###############################################################################
# MODULE: vpc/outputs.tf
###############################################################################
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "sg_upload_id" {
  value = aws_security_group.sg_upload.id
}

output "sg_crop_id" {
  value = aws_security_group.sg_crop.id
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}
