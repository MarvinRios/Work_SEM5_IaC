data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

###############################################################################
# VPC
###############################################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_resolution = true
  enable_dns_hostnames  = true

  tags = {
    Name = "image-processor-${var.environment}-vpc"
  }
}

###############################################################################
# Internet Gateway
###############################################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "image-processor-${var.environment}-igw"
  }
}

###############################################################################
# Public Subnets
###############################################################################
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "image-processor-${var.environment}-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = local.az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "image-processor-${var.environment}-public-b"
    Tier = "public"
  }
}

###############################################################################
# Private Subnets
###############################################################################
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = local.az_a

  tags = {
    Name = "image-processor-${var.environment}-private-a"
    Tier = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = local.az_b

  tags = {
    Name = "image-processor-${var.environment}-private-b"
    Tier = "private"
  }
}

###############################################################################
# Elastic IP & NAT Gateway (solo 1 — AZ-a)
###############################################################################
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = {
    Name = "image-processor-${var.environment}-eip-nat-a"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "image-processor-${var.environment}-nat-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

###############################################################################
# Route Tables — Public
###############################################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "image-processor-${var.environment}-rt-public"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Route Tables — Private (ambas AZs apuntan al mismo NAT GW para ahorrar)
###############################################################################
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "image-processor-${var.environment}-rt-private-a"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "image-processor-${var.environment}-rt-private-b"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

###############################################################################
# Security Groups
###############################################################################

# SG para upload-lambda: sin inbound, outbound solo HTTPS a S3 y SQS
resource "aws_security_group" "sg_upload" {
  name        = "sg-upload-lambda-${var.environment}"
  description = "SG for upload-lambda: no inbound, HTTPS outbound only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to S3 Gateway Endpoint and internet (for SQS via NAT)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-upload-lambda-${var.environment}"
  }
}

# SG para crop-lambda: sin inbound, outbound solo HTTPS
resource "aws_security_group" "sg_crop" {
  name        = "sg-crop-lambda-${var.environment}"
  description = "SG for crop-lambda: no inbound, HTTPS outbound only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to S3 and SQS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-crop-lambda-${var.environment}"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_a.id,
    aws_route_table.private_b.id,
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3Access"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "image-processor-${var.environment}-vpce-s3"
  }
}