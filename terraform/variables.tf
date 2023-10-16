variable "acl" {
  type        = string
  default     = "private"
  description = "The canned ACL to apply. We recommend `private` to avoid exposing sensitive information. Conflicts with grant"
}

variable "policy" {
  type        = string
  default     = ""
  description = "A valid bucket policy JSON document. Note that if the policy document is not specific enough (but still valid), Terraform may view the policy as constantly changing in a terraform plan. In this case, please make sure you use the verbose/specific version of the policy"
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "A boolean string that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable"
}

variable "sse_algorithm" {
  type        = string
  default     = "AES256"
  description = "The server-side encryption algorithm to use. Valid values are `AES256` and `aws:kms`"
}

variable "kms_master_key_arn" {
  type        = string
  default     = ""
  description = "The AWS KMS master key ARN used for the `SSE-KMS` encryption. This can only be used when you set the value of `sse_algorithm` as `aws:kms`. The default aws/s3 AWS KMS master key is used if this element is absent while the `sse_algorithm` is `aws:kms`"
}

variable "allowed_bucket_actions" {
  type        = list(string)
  default     = ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:GetBucketLocation", "s3:AbortMultipartUpload"]
  description = "List of actions the user is permitted to perform on the S3 bucket"
}

variable "allow_encrypted_uploads_only" {
  type        = bool
  default     = false
  description = "Set to `true` to prevent uploads of unencrypted objects to S3 bucket"
}

variable "prefix" {
  type        = string
  default     = ""
  description = "Prefix identifying one or more objects to which the rule applies"
}

variable "block_public_acls" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the blocking of new public access lists on the bucket"
}

variable "block_public_policy" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the blocking of new public policies on the bucket"
}

variable "ignore_public_acls" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the ignoring of public access lists on the bucket"
}

variable "restrict_public_buckets" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the restricting of making the bucket public"
}

variable "versioning_enabled" {
  type        = bool
  default     = false
  description = "Enable bucket versioning"
}

variable "replication_configuration" {
  default     = []
  description = "Replication configuration for this bucket"
  type = list(object({
    iam_role_arn = string
    rules = object({
      id               = string
      prefix           = string
      status           = string
      dest_bucket      = string
      storage_class    = string
      owner_account_id = string
      kms_key_id       = string
    })
  }))
}

variable "grants" {
  default     = []
  description = "Access Control Lists about who can access your bucket. Conflicts with ACL"
  type = list(object({
    id          = string
    type        = string
    permissions = list(string)
  }))
}

variable "expiry_lifecycle_rules" {
  type = list(object({
    id      = string
    prefix  = string
    enabled = bool
    expiration = object({
      date = string
      days = number
    })
  }))
  default = []
}

variable "public_access_block_enabled" {
  type        = bool
  description = "Whether to include a default public access block or not."
  default     = true
}

variable "logging_enabled" {
  type        = bool
  description = "Whether to include a s3 logging with this module or not."
  default     = false
}

variable "logging_transition_days" {
  type        = string
  description = "Length in days before transitioning logs."
  default     = "30"
}

variable "logging_storage_class" {
  type        = string
  description = "Log bucket storage class."
  default     = "STANDARD_IA"
}
