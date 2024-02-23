variable "name" {
  type        = string
  description = "name for the resources"
  default     = "page-insights"
}

variable "image_tag" {
  type        = string
  description = "container image tag"
  default     = "0.1.0"
}
