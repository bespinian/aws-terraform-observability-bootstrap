# ======================================================================================================================
# Run from the Management/Root Account
# ======================================================================================================================

locals {
  # Flatten domains × workloads × environments into a single map
  # Key format: "coffeeshop-order-dev", "coffeeshop-barista-prod", etc.
  workload_accounts = merge([
    for domain_name, domain in var.domains : {
      for domain_workload_env in setproduct([domain_name], domain.workloads, var.environments) :
      "${domain_workload_env[0]}-${domain_workload_env[1]}-${domain_workload_env[2]}" => {
        domain      = domain_workload_env[0]
        workload    = domain_workload_env[1]
        environment = domain_workload_env[2]
      }
    }
  ]...)

  workload_account_parent_ids = {
    for k, v in local.workload_accounts :
    k => (
      var.archive_accounts
      ? var.archive_ou_id
      : aws_organizations_organizational_unit.envs[v.environment].id
    )
  }

  observability_parent_id = (
    var.archive_accounts
    ? var.archive_ou_id
    : aws_organizations_organizational_unit.shared_services.id
  )
}

data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "main" {}

# ======================================================================================================================
# S3 Org Terraform State
# ======================================================================================================================

resource "aws_s3_bucket" "org_state" {
  bucket = "org-state-${data.aws_caller_identity.current.account_id}"
  # Enables bucket deletion without manually emptying it first.
  # Required for fully automated teardown of Terraform state infrastructure.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.org_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.org_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ======================================================================================================================
# Root-level Organizational Units
# ======================================================================================================================

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads"
  parent_id = data.aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "shared_services" {
  name      = "shared-services"
  parent_id = data.aws_organizations_organization.main.roots[0].id
}

# ======================================================================================================================
# Workloads Sub-OUs (Environment-based)
# ======================================================================================================================

resource "aws_organizations_organizational_unit" "envs" {
  for_each = toset(var.environments)

  name      = each.key
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# ======================================================================================================================
# DELEGATED ADMINISTRATOR
# This configuration delegates CloudFormation StackSets administration to the observability account,
# allowing it to deploy StackSets across the organization without needing management/root account credentials.
# ======================================================================================================================

resource "aws_organizations_delegated_administrator" "stacksets" {
  account_id        = aws_organizations_account.observability.id
  service_principal = "member.org.stacksets.cloudformation.amazonaws.com"
}

# ======================================================================================================================
# SCP
# ======================================================================================================================
data "aws_iam_policy_document" "protect_non_workloads" {
  # Block Service-Managed StackSets (the automation role) from running outside the Workloads OU.
  statement {
    sid       = "DenyStackSetExecOutsideWorkloads"
    effect    = "Deny"
    actions   = ["cloudformation:*"]
    resources = ["*"]

    # Target the auto-generated StackSet roles
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:role/stacksets-exec-*"]
    }

    # Exception: Allow if the account is in the Workloads OU path
    condition {
      test     = "ForAnyValue:StringNotLike"
      variable = "aws:PrincipalOrgPaths"
      values = [
        "${data.aws_organizations_organization.main.id}/${data.aws_organizations_organization.main.roots[0].id}/${aws_organizations_organizational_unit.workloads.id}/*"
      ]
    }
  }
}

resource "aws_organizations_policy" "protect_non_workloads" {
  name        = "BlockObservabilityAndStackSetsOutsideWorkloads"
  description = "Restricts StackSet execution and OAM Linking to the Workloads OU only"
  type        = "SERVICE_CONTROL_POLICY"

  content = data.aws_iam_policy_document.protect_non_workloads.json
}

resource "aws_organizations_policy_attachment" "root_scp_attach" {
  policy_id = aws_organizations_policy.protect_non_workloads.id
  target_id = data.aws_organizations_organization.main.roots[0].id
}

# ======================================================================================================================
# Accounts
# ======================================================================================================================
resource "aws_organizations_account" "workload_accounts" {
  for_each = local.workload_accounts

  name      = each.key
  email     = "${var.organization_email_prefix}+${each.key}@${var.organization_email_domain}"
  parent_id = local.workload_account_parent_ids[each.key]

  close_on_deletion = true

  tags = {
    domain       = each.value.domain
    workload     = each.value.workload
    environment  = each.value.environment
    account-type = "workload"
    lifecycle    = var.archive_accounts ? "archived" : "active"
  }
}

resource "aws_organizations_account" "observability" {
  name      = "observability"
  email     = "${var.organization_email_prefix}+observability2@${var.organization_email_domain}"
  parent_id = local.observability_parent_id

  close_on_deletion = true

  tags = {
    domain       = "observability"
    account-type = "shared"
    environment  = "prod"
    lifecycle    = var.archive_accounts ? "archived" : "active"
  }
}