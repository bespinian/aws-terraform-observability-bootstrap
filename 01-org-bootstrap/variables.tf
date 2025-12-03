variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environments" {
  description = ""
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "organization_email_prefix" {
  description = "Email prefix for AWS accounts (e.g., 'coffeeshop' for coffeeshop+dev@example.com)"
  type        = string
}

variable "organization_email_domain" {
  description = "Email domain for AWS accounts (e.g., 'example.com')"
  type        = string
}

variable "domains" {
  description = <<-EOT
    Map of Business Domains and their specific Workloads.

    A distinct AWS Account will be created for every combination of:
    Domain × Workload × Environment (dev, staging, prod).

    These accounts are automatically placed into the corresponding Environment OU
    (e.g., 'workloads/dev', 'workloads/prod').

    Naming Convention: {domain}-{workload}-{environment}

    Example:
    {
      "coffeeshop": {
        "workloads": ["order", "barista"]
      }
    }
  EOT
  type = map(object({
    workloads = list(string)
  }))
}

variable "archive_ou_id" {
  description = "ID of an existing 'archive' OU created outside of Terraform. If set and archive_accounts=true, accounts are moved there before destroy."
  type        = string
}

variable "archive_accounts" {
  description = "If true, move all managed accounts into the archive OU before teardown."
  type        = bool
  default     = false
}