###############################################################################
# HTTP API
###############################################################################
resource "aws_apigatewayv2_api" "main" {
  name          = "image-processor-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "Image Processor API — ${var.environment}"

  # CORS habilitado según diagrama
  cors_configuration {
    allow_origins = ["*"]           # En prod, restringir a dominio específico
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Requested-With"]
    max_age       = 300
  }

  tags = {
    Name = "image-processor-${var.environment}-api"
  }
}

###############################################################################
# CloudWatch Log Group para access logs del API Gateway
###############################################################################
resource "aws_cloudwatch_log_group" "apigw_logs" {
  name              = "/aws/apigateway/image-processor-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/aws/apigateway/image-processor-${var.environment}"
  }
}

###############################################################################
# Stage $default con auto-deploy y access logs en JSON
###############################################################################
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # Access logs en formato JSON
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn
    # Formato JSON completo para observabilidad
  }

  # Throttling a nivel de stage
  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
    # Logging level solo disponible en REST API, no HTTP API
    detailed_metrics_enabled = false  # true incurre en costo adicional
  }

  tags = {
    Name = "image-processor-${var.environment}-stage-default"
  }
}

###############################################################################
# Lambda Integration (Proxy, Payload Format 2.0)
###############################################################################
resource "aws_apigatewayv2_integration" "upload_lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.upload_lambda_invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"      # Payload format 2.0
}

###############################################################################
# Ruta POST /upload
###############################################################################
resource "aws_apigatewayv2_route" "post_upload" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload_lambda.id}"
}

###############################################################################
# Lambda Permission — permite que API Gateway invoque la Lambda
###############################################################################
resource "aws_lambda_permission" "apigw_invoke_upload" {
  statement_id  = "AllowAPIGatewayInvoke-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = var.upload_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*/upload"
}
