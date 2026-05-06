###############################################################################
# ROOT outputs.tf
###############################################################################

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3.bucket_name
}

output "upload_lambda_name" {
  description = "Upload Lambda function name"
  value       = module.lambda_upload.function_name
}

output "crop_lambda_name" {
  description = "Crop Lambda function name"
  value       = module.lambda_crop.function_name
}

output "sqs_queue_url" {
  description = "Main SQS queue URL"
  value       = module.sqs.queue_url
}

output "sqs_dlq_url" {
  description = "Dead-letter queue URL"
  value       = module.sqs.dlq_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
