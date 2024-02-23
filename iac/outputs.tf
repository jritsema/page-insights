output "lambda-app" {
  value = module.lambda.lambda_function_arn
}

output "lambda_llm" {
  value = module.lambda_llm.lambda_function_arn
}

output "endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
