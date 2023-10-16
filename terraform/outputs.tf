output "aws_access_key" {
  value     = aws_iam_access_key.this.id
  sensitive = true
}

output "aws_access_secret" {
  value     = aws_iam_access_key.this.secret
  sensitive = true
}

output "aws_bucket_id" {
  value = aws_s3_bucket.this.id
}