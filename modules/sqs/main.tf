###############################################################################
# Dead-Letter Queue
###############################################################################
resource "aws_sqs_queue" "dlq" {
  name                       = "image-processor-${var.environment}-image-dlq"
  message_retention_seconds  = 1209600  # 14 días
  # Sin SQS FIFO — Standard queue

  tags = {
    Name = "image-processor-${var.environment}-image-dlq"
  }
}

###############################################################################
# Main Queue
###############################################################################
resource "aws_sqs_queue" "main" {
  name                       = "image-processor-${var.environment}-image-queue"
  visibility_timeout_seconds = 360        # 6× el timeout de crop-lambda (60 s)
  message_retention_seconds  = 86400      # 1 día
  receive_wait_time_seconds  = 20         # Long polling: reduce llamadas vacías
  max_message_size           = 262144     # 256 KB máximo

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3              # Después de 3 intentos fallidos → DLQ
  })

  tags = {
    Name = "image-processor-${var.environment}-image-queue"
  }
}

###############################################################################
# SQS Queue Policy — Permite que S3 publique notificaciones
###############################################################################
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::*"
          }
        }
      }
    ]
  })
}
