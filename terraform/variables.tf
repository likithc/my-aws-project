variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "my-aws-demo-app"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
