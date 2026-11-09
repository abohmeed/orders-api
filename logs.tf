# AI-generated change for the "app logs" feature (DSAI-07).
# Copied into the repo root on a new branch off camera. Breaks two policies on purpose.

resource "aws_s3_bucket" "logs" {
  bucket = "dsai-app-logs-${var.env}"
}

resource "aws_iam_role_policy" "logs" {
  name = "app-logs"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
    }]
  })
}
