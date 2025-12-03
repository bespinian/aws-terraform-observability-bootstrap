output "tf_state_bucket_name" {
  description = "The name of the S3 bucket created to store Terraform state. Copy this value into versions.tf."
  value       = aws_s3_bucket.org_state.id
}

output "workloads_ou_id" {
  description = "Workloads OU ID - target this OU for StackSet deployment"
  value       = aws_organizations_organizational_unit.workloads.id
}