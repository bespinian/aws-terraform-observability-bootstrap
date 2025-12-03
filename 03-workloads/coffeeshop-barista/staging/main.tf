terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }


  # 1. Run 'terraform apply' with this block commented out (Local State).
  # 2. Copy the 'tf_state_bucket_name' output value (e.g., terraform-state-123456789012).
  # 3. Paste it into the 'bucket' field below.
  # 4. Uncomment this block.
  # 5. Run 'terraform init' and type 'yes' to migrate state to S3.

  # backend "s3" {
  #   bucket  = "terraform-state-123456789012"
  #   key     = "coffeeshop-barista-tf-state/terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  #
  #   # Native Locking (No DynamoDB required)
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      managed-by  = "terraform"
      environment = "staging"
      workload    = "coffeeshop-barista"
    }
  }
}

module "order_lambda" {
  source = "../../modules/serverless-app"

  function_name = "coffeeshop-barista-staging"
  workload      = "coffeeshop-barista"
}

output "tf_state_bucket_name" {
  description = "The name of the S3 bucket created to store Terraform state. Copy this value into terraform.backend.s3"
  value       = module.order_lambda.tf_state_bucket_name
}