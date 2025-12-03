# ======================================================================================================================
# Run from the observability Account
# ======================================================================================================================

# ======================================================================================================================
# Data Sources
# ======================================================================================================================

data "aws_organizations_organization" "main" {}

data "aws_caller_identity" "current" {}

# ======================================================================================================================
# S3 Org Terraform State
# ======================================================================================================================

resource "aws_s3_bucket" "observability_state" {
  bucket = "observability-state-${data.aws_caller_identity.current.account_id}"
  # Enables bucket deletion without manually emptying it first.
  # Required for fully automated teardown of Terraform state infrastructure.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.observability_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.observability_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ======================================================================================================================
# Observability Access Manager Sink
# ======================================================================================================================

resource "aws_oam_sink" "central" {
  name = "central-observability-sink"
}

data "aws_iam_policy_document" "sink_policy" {
  statement {
    sid       = "AllowOrganizationToLink"
    actions   = ["oam:CreateLink", "oam:UpdateLink"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "oam:ResourceTypes"
      values = [
        "AWS::CloudWatch::Metric",
        "AWS::Logs::LogGroup",
        "AWS::XRay::Trace"
      ]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "aws:PrincipalOrgPaths"
      values   = ["${data.aws_organizations_organization.main.id}/${data.aws_organizations_organization.main.roots[0].id}/${var.workloads_ou_id}/*"]
    }
  }
}

resource "aws_oam_sink_policy" "allow_organization" {
  sink_identifier = aws_oam_sink.central.id
  policy          = data.aws_iam_policy_document.sink_policy.json
}

# ======================================================================================================================
# CloudFormation StackSet
# ======================================================================================================================

resource "aws_cloudformation_stack_set" "oam_links" {
  name             = "observability-oam-links"
  description      = "Automatically deploys OAM links in all workload accounts"
  permission_model = "SERVICE_MANAGED"
  call_as          = "DELEGATED_ADMIN"

  capabilities = ["CAPABILITY_IAM"]

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  parameters = {
    SinkIdentifier = aws_oam_sink.central.arn
    SinkAccountId  = data.aws_caller_identity.current.account_id
  }

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "OAM Link to Central Observability Account"

    Parameters = {
      SinkIdentifier = {
        Type = "String"
      }
      SinkAccountId = { Type = "String" }
    }

    Conditions = {
      # Returns TRUE if the account running this stack is NOT the Sink Account
      IsNotSinkAccount = {
        "Fn::Not" = [{
          "Fn::Equals" = [
            { "Ref" = "AWS::AccountId" },
            { "Ref" = "SinkAccountId" }
          ]
        }]
      }
    }

    Resources = {
      OAMLink = {
        Type      = "AWS::Oam::Link"
        Condition = "IsNotSinkAccount"
        Properties = {
          LabelTemplate = "$AccountName"
          ResourceTypes = [
            "AWS::CloudWatch::Metric",
            "AWS::Logs::LogGroup",
            "AWS::XRay::Trace"
          ]
          SinkIdentifier = {
            Ref = "SinkIdentifier"
          }
        }
      }
    }
  })

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "workloads_ou" {
  stack_set_name            = aws_cloudformation_stack_set.oam_links.name
  call_as                   = "DELEGATED_ADMIN"
  stack_set_instance_region = var.region

  deployment_targets {
    organizational_unit_ids = [var.workloads_ou_id]
  }

  operation_preferences {
    max_concurrent_count    = 10
    failure_tolerance_count = 0
    region_concurrency_type = "PARALLEL"
  }

  depends_on = [aws_oam_sink_policy.allow_organization]
}
