terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "image-processor"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

###############################################################################
# VPC
###############################################################################
module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  aws_region  = var.aws_region
}

###############################################################################
# IAM
###############################################################################
module "iam" {
  source      = "./modules/iam"
  environment = var.environment
  s3_bucket_arn = module.s3.bucket_arn
}

###############################################################################
# S3
###############################################################################
module "s3" {
  source         = "./modules/s3"
  environment    = var.environment
  suffix         = var.bucket_suffix
  sqs_queue_arn  = module.sqs.queue_arn
}

###############################################################################
# SQS
###############################################################################
module "sqs" {
  source      = "./modules/sqs"
  environment = var.environment
  # Se pasa el ARN del alarm topic después de crearlo en cloudwatch
  alarm_sns_arn = module.cloudwatch.alarm_sns_arn
}

###############################################################################
# Lambda — Upload
###############################################################################
module "lambda_upload" {
  source              = "./modules/lambda"
  environment         = var.environment
  function_name_suffix = "upload"
  handler             = "index.handler"
  runtime             = "nodejs20.x"
  memory_size         = 256
  timeout             = 30
  lambda_role_arn     = module.iam.upload_role_arn
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.vpc.sg_upload_id]
  source_dir          = "${path.module}/lambdas/upload"
  environment_variables = {
    S3_BUCKET     = module.s3.bucket_name
    UPLOAD_PREFIX = "uploads/"
    ENVIRONMENT   = var.environment
  }
  log_retention_days = 14
}

###############################################################################
# Lambda — Crop
###############################################################################
module "lambda_crop" {
  source              = "./modules/lambda"
  environment         = var.environment
  function_name_suffix = "crop"
  handler             = "index.handler"
  runtime             = "nodejs20.x"
  memory_size         = 512
  timeout             = 60
  lambda_role_arn     = module.iam.crop_role_arn
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.vpc.sg_crop_id]
  source_dir          = "${path.module}/lambdas/crop"
  environment_variables = {
    S3_BUCKET         = module.s3.bucket_name
    PROCESSED_PREFIX  = "processed/"
    ENVIRONMENT       = var.environment
  }
  log_retention_days = 14

  # SQS Event Source Mapping
  sqs_queue_arn     = module.sqs.queue_arn
  enable_sqs_trigger = true
  sqs_batch_size    = 5
}

###############################################################################
# API Gateway
###############################################################################
module "api_gateway" {
  source            = "./modules/api_gateway"
  environment       = var.environment
  upload_lambda_arn         = module.lambda_upload.function_arn
  upload_lambda_invoke_arn  = module.lambda_upload.invoke_arn
  upload_lambda_name        = module.lambda_upload.function_name
  throttling_burst_limit    = var.api_throttling_burst
  throttling_rate_limit     = var.api_throttling_rate
  log_retention_days        = 14
}

###############################################################################
# CloudWatch Alarms & Log Groups
###############################################################################
module "cloudwatch" {
  source          = "./modules/cloudwatch"
  environment     = var.environment
  dlq_queue_name  = module.sqs.dlq_name
}
