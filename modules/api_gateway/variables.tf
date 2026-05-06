variable "environment"              { type = string }
variable "upload_lambda_arn"        { type = string }
variable "upload_lambda_invoke_arn" { type = string }
variable "upload_lambda_name"       { type = string }
variable "throttling_burst_limit"   { type = number }
variable "throttling_rate_limit"    { type = number }
variable "log_retention_days"       { type = number; default = 14 }
