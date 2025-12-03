output "tf_state_bucket_name" {
  description = "The name of the S3 bucket created to store Terraform state. Copy this value into versions.tf."
  value       = aws_s3_bucket.observability_state.id
}

output "verification_commands" {
  description = "AWS CLI commands to verify the OAM setup"
  value = {
    list_attached_links = "aws oam list-attached-links --sink-identifier ${aws_oam_sink.central.arn}"
    list_sinks          = "aws oam list-sinks"
  }
}
