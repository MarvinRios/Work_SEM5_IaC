resource "aws_s3_bucket" "images" {
  bucket = "image-processor-${var.environment}-images-${var.suffix}"

  # Fuerza que Terraform elimine el bucket aunque tenga objetos (útil en labs)
  force_destroy = true

  tags = {
    Name = "image-processor-${var.environment}-images-${var.suffix}"
  }
}

###############################################################################
# Block ALL public access — acceso completamente privado
###############################################################################
resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# Server-Side Encryption — AES-256 
###############################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

###############################################################################
# Versioning 
###############################################################################
resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

###############################################################################
# Lifecycle Rules
###############################################################################
resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  # Regla 1: uploads
  rule {
    id     = "expire-uploads-30-days"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 30
    }

    # Limpieza de versiones anteriores (evita acumulación de costos)
    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    # Elimina marcadores de eliminación huérfanos
    expiration {
      expired_object_delete_marker = true
    }
  }

  # Regla 2: processed
  rule {
    id     = "expire-processed-90-days"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

###############################################################################
# S3 Event Notification → SQS
# Cuando se crea cualquier objeto en uploads/, dispara notificación a SQS
###############################################################################
resource "aws_s3_bucket_notification" "to_sqs" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = var.sqs_queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_s3_bucket_public_access_block.images]
}
