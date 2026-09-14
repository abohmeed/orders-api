output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.order_exports.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.order_exports.arn
}

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.orders_api_role.arn
}
