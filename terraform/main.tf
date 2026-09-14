resource "aws_s3_bucket" "order_exports" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "orders-api-exports"
  }
}

resource "aws_s3_bucket_versioning" "order_exports" {
  bucket = aws_s3_bucket.order_exports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "order_exports" {
  bucket = aws_s3_bucket.order_exports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "orders_api_role" {
  name = "orders-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "orders_api_s3_policy" {
  name = "orders-api-s3-policy"
  role = aws_iam_role.orders_api_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.order_exports.arn,
          "${aws_s3_bucket.order_exports.arn}/*"
        ]
      }
    ]
  })
}
