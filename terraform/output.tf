output "app_runner_service_url" {
  description = "HTTPS URL of the App Runner service"
  value       = aws_apprunner_service.main.service_url
}

output "ecr_repository_url" {
  description = "ECR repository URL (without image tag) for docker push"
  value       = aws_ecr_repository.app_repository.repository_url
}