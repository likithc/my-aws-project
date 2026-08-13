output "ecr_repository_url" {
  description = "The URL of the ECR repository to push Docker images"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "ecr_repository_arn" {
  description = "The ARN of the ECR repository"
  value       = aws_ecr_repository.app_repo.arn
}
