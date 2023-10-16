resource "aws_iam_user" "this" {
  name = "ciBuildCache"
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

resource "aws_iam_policy" "this" {
  name        = "ciBuildCache"
  description = "Used by CI to store caches in S3."
  policy      = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": ["${aws_s3_bucket.this.arn}"]
    },
    {
      "Effect": "Allow",
      "Action": [ 
        "s3:DeleteObject",
        "s3:GetBucketLocation", 
        "s3:GetObject", 
        "s3:ListBucket", 
        "s3:PutObject", 
        "s3:PutObjectAcl",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": ["${aws_s3_bucket.this.arn}/*"]
    }
  ]
}
EOF
}


resource "aws_iam_user_policy_attachment" "this" {
  user       = aws_iam_user.this.name
  policy_arn = aws_iam_policy.this.arn
}