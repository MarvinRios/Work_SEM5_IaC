output "upload_role_arn" {
  value = aws_iam_role.upload_lambda_role.arn
}

output "crop_role_arn" {
  value = aws_iam_role.crop_lambda_role.arn
}
