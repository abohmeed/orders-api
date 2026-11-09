# AI-generated change for the "app logs" feature (DSAI-07).
# Copied into the repo root on a new branch off camera.

resource "aws_s3_bucket" "logs" {
  bucket = "dsai-app-logs-${var.env}"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role_policy" "logs" {
  name = "app-logs"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.logs.arn}/*"
    }]
  })
}
