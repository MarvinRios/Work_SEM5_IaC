###############################################################################
# Empaquetar código fuente como ZIP
###############################################################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${var.source_dir}/src"
  output_path = "${path.root}/.terraform/tmp/${var.environment}-${var.function_name_suffix}.zip"
}

###############################################################################
# Lambda Function
###############################################################################
resource "aws_lambda_function" "this" {
  function_name = "image-processor-${var.environment}-${var.function_name_suffix}"
  description   = "Image processor ${var.function_name_suffix} function — ${var.environment}"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = var.handler
  runtime     = var.runtime
  memory_size = var.memory_size
  timeout     = var.timeout
  role        = var.lambda_role_arn

  # Lambda dentro de VPC (private subnets)
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = var.environment_variables
  }


  tags = {
    Name     = "image-processor-${var.environment}-${var.function_name_suffix}"
    Function = var.function_name_suffix
  }
}

###############################################################################
# CloudWatch Log Group (creado explícitamente para controlar la retención)
###############################################################################
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/image-processor-${var.environment}-${var.function_name_suffix}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/aws/lambda/image-processor-${var.environment}-${var.function_name_suffix}"
  }
}

###############################################################################
# SQS Event Source Mapping (solo para crop-lambda)
# batch_size = 5, ReportBatchItemFailures para reintentos parciales
###############################################################################
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count = var.enable_sqs_trigger ? 1 : 0

  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = var.sqs_batch_size
  enabled          = true

  # ReportBatchItemFailures: permite que la función reporte solo los mensajes
  # fallidos en lugar de reintentar todo el batch
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5  # Límite de concurrencia para SQS polling en lab
  }
}
