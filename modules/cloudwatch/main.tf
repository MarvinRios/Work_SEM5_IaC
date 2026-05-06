###############################################################################
# MODULE: cloudwatch/main.tf
#
# Recursos:
#   - SNS Topic para notificaciones de alarma
#   - CloudWatch Alarm: DLQ mensajes visibles > 0
###############################################################################

###############################################################################
# SNS Topic para la alarma del DLQ
###############################################################################
resource "aws_sns_topic" "dlq_alarm_topic" {
  name = "image-processor-${var.environment}-dlq-alarm-topic"

  tags = {
    Name = "image-processor-${var.environment}-dlq-alarm-topic"
  }
}

###############################################################################
# CloudWatch Alarm — DLQ: cualquier mensaje visible dispara la alarma
###############################################################################
resource "aws_cloudwatch_metric_alarm" "dlq_messages_alarm" {
  alarm_name          = "image-processor-${var.environment}-dlq-messages-alarm"
  alarm_description   = "Alarma: hay mensajes visibles en la DLQ. Revisar errores en crop-lambda."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60      # 60 segundos según diagrama
  statistic           = "Sum"
  threshold           = 0       # Cualquier mensaje dispara la alarma
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_queue_name
  }

  alarm_actions = [aws_sns_topic.dlq_alarm_topic.arn]
  ok_actions    = [aws_sns_topic.dlq_alarm_topic.arn]

  tags = {
    Name = "image-processor-${var.environment}-dlq-messages-alarm"
  }
}
