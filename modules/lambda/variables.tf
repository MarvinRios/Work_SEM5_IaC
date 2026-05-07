variable "environment"          { type = string }
variable "function_name_suffix" { type = string }
variable "handler"              { type = string }
variable "runtime"              { type = string }
variable "memory_size"          { type = number }
variable "timeout"              { type = number }
variable "lambda_role_arn"      { type = string }
variable "subnet_ids"           { type = list(string) }
variable "security_group_ids"   { type = list(string) }
variable "source_dir"           { type = string }
variable "log_retention_days"   { type = number; default = 14 }

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "enable_sqs_trigger" {
  type    = bool
  default = false
}

variable "sqs_queue_arn" {
  type    = string
  default = ""
}

variable "sqs_batch_size" {
  type    = number
  default = 5
}
