###############################################################################
# ROOT variables.tf
###############################################################################

variable "environment" {
  description = "Deployment environment: dev, qa, or prod"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_suffix" {
  description = "Suffix para el nombre del bucket S3 (debe ser único globalmente)"
  type        = string
  # Ejemplo: "abc123" → bucket: image-processor-dev-images-abc123
}

variable "api_throttling_rate" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 100

}

variable "api_throttling_burst" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 50
}
