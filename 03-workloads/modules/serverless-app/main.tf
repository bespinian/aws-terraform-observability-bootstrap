data "aws_caller_identity" "current" {}

# ======================================================================================================================
# S3 Org Terraform State
# ======================================================================================================================

resource "aws_s3_bucket" "state" {
  bucket = "terraform-state-${data.aws_caller_identity.current.account_id}"
  # Enables bucket deletion without manually emptying it first.
  # Required for fully automated teardown of Terraform state infrastructure.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  version       = "v8.1.2"
  publish       = true
  function_name = var.function_name
  handler       = "lambda.handler"
  runtime       = "python3.12"

  environment_variables = {
    WORKLOAD = var.workload
  }

  source_path = [
    "${path.module}/lambda.py"
  ]
}