provider "aws" {
  default_tags {
    tags = {
      "app" = var.name
    }
  }
}

locals {
  llm = "${var.name}-llm"
}

resource "aws_s3_bucket" "main" {
  bucket        = "${var.name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          "AWS" = [
            module.lambda.lambda_role_arn,
          ]
        }
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn
        ]
      },
      {
        Effect = "Allow"
        Principal = {
          "AWS" = [
            module.lambda.lambda_role_arn,
            module.lambda_llm.lambda_role_arn,
          ]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.main.arn}/*"
        ]
      }
    ]
  })
}

provider "docker" {
  registry_auth {
    address  = format("%v.dkr.ecr.%v.amazonaws.com", data.aws_caller_identity.current.account_id, data.aws_region.current.name)
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

##################################
# App
##################################

# api gateway terraform
resource "aws_apigatewayv2_api" "lambda" {
  name          = var.name
  description   = var.name
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_headers     = [
      "*"
    ]
    allow_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "POST",
      "DELETE",
    ]
    allow_origins = [
      "*",
    ]
    expose_headers = []
    max_age        = 0
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apig.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
  depends_on = [aws_cloudwatch_log_group.apig]
}

resource "aws_apigatewayv2_integration" "app" {
  api_id           = aws_apigatewayv2_api.lambda.id
  integration_uri  = module.lambda.lambda_function_invoke_arn
  integration_type = "AWS_PROXY"
}

resource "aws_apigatewayv2_route" "any" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 5
}

resource "aws_cloudwatch_log_group" "apig" {
  name              = "${var.name}-debug-apigateway"
  retention_in_days = 7
}

module "docker_image" {
  source = "terraform-aws-modules/lambda/aws//modules/docker-build"

  create_ecr_repo = true
  ecr_repo        = var.name
  image_tag       = var.image_tag
  source_path     = "../app/"
  platform        = "linux/amd64"
}

module "lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name  = var.name
  description    = var.name
  create_package = false
  package_type   = "Image"
  image_uri      = module.docker_image.image_uri
  architectures  = ["x86_64"]
  memory_size    = 512
  timeout        = 120

  environment_variables = {
    "S3_BUCKET"       = aws_s3_bucket.main.id
    "LAMBDA_FUNCTION" = module.lambda_llm.lambda_function_arn
  }

  # app lambda needs to call llm lambda
  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [module.lambda_llm.lambda_function_arn]
    }]
  })

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service = "apigateway"
      # source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
      source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
    }
  }
}

##################################
# LLM
##################################

module "docker_image_llm" {
  source = "terraform-aws-modules/lambda/aws//modules/docker-build"

  create_ecr_repo = true
  ecr_repo        = "${var.name}-llm"
  image_tag       = var.image_tag
  source_path     = "../llm/"
  platform        = "linux/amd64"
}

module "lambda_llm" {
  source = "terraform-aws-modules/lambda/aws"

  function_name      = local.llm
  description        = local.llm
  create_package     = false
  package_type       = "Image"
  image_uri          = module.docker_image_llm.image_uri
  architectures      = ["x86_64"]
  timeout            = 300
  memory_size        = 512
  attach_policy_json = true

  # llm lambda needs to call foundation model
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = ["arn:aws:bedrock:us-east-1::foundation-model/*"]
    }]
  })
}
