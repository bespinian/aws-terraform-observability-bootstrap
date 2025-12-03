terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  # 1. Run 'terraform apply' with this block commented out (Local State).
  # 2. Copy the 'tf_state_bucket_name' output value (e.g., observability-state-123456789012).
  # 3. Paste it into the 'bucket' field below.
  # 4. Uncomment this block.
  # 5. Run 'terraform init' and type 'yes' to migrate state to S3.

  # backend "s3" {
  #   bucket  = "observability-state-123456789012"
  #   key     = "02-observability/terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  #
  #   # Native Locking (No DynamoDB required)
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      managed-by  = "terraform"
      environment = "prod"
    }
  }
}