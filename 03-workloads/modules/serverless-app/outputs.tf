output "tf_state_bucket_name" {
  description = "The name of the S3 bucket created to store Terraform state. Copy this value into terraform.backend.s3"
  value       = aws_s3_bucket.state.id
}