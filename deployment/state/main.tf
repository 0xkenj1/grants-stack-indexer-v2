provider "aws" {
  region = "us-east-2"
}
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.app_name}-${var.app_environment}-terraform-state"
  account_id  = data.aws_caller_identity.current.account_id
}

module "s3_terraform_state" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.4.0"

  bucket = local.bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.account_id}:root"
        },
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        "Resource" : [
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*"
        ]
      }
    ]
  })

  tags = {
    Environment = var.app_environment
    Name        = local.bucket_name
  }
}
