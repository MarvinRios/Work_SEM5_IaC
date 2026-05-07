###############################################################################
# Upload Lambda Role
###############################################################################
resource "aws_iam_role" "upload_lambda_role" {
  name = "upload-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "upload-lambda-role-${var.environment}"
  }
}

# Políticas AWS gestionadas para Lambda básica + VPC
resource "aws_iam_role_policy_attachment" "upload_basic_exec" {
  role       = aws_iam_role.upload_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "upload_vpc_exec" {
  role       = aws_iam_role.upload_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Política inline: solo PutObject en uploads/
resource "aws_iam_role_policy" "upload_s3_policy" {
  name = "upload-s3-policy-${var.environment}"
  role = aws_iam_role.upload_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowS3PutObjectUploads"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.s3_bucket_arn}/uploads/*"
      }
    ]
  })
}

###############################################################################
# Crop Lambda Role
###############################################################################
resource "aws_iam_role" "crop_lambda_role" {
  name = "crop-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "crop-lambda-role-${var.environment}"
  }
}

resource "aws_iam_role_policy_attachment" "crop_basic_exec" {
  role       = aws_iam_role.crop_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc_exec" {
  role       = aws_iam_role.crop_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Política inline: S3 (Get uploads + Put processed) + SQS
resource "aws_iam_role_policy" "crop_s3_sqs_policy" {
  name = "crop-s3-sqs-policy-${var.environment}"
  role = aws_iam_role.crop_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3GetObjectUploads"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "${var.s3_bucket_arn}/uploads/*"
      },
      {
        Sid    = "AllowS3PutObjectProcessed"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${var.s3_bucket_arn}/processed/*"
      },
      {
        Sid    = "AllowSQSOperations"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        # El ARN de la cola se pasa como variable desde el módulo sqs
        Resource = "*"
      }
    ]
  })
}
