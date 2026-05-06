output "alarm_sns_arn" {
  value = aws_sns_topic.dlq_alarm_topic.arn
}

output "dlq_alarm_name" {
  value = aws_cloudwatch_metric_alarm.dlq_messages_alarm.alarm_name
}
