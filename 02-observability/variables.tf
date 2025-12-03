variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "workloads_ou_id" {
  description = "Workloads OU ID - obtained from 01-org-bootstrap outputs"
  type        = string
}