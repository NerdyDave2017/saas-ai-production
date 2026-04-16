# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  app_secret_arn = aws_secretsmanager_secret.app_runner_secret.arn

  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECR — force_delete allows terraform destroy even when images exist
resource "aws_ecr_repository" "app_repository" {
  name         = local.name_prefix
  force_delete = true
}

resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${local.name_prefix}-service-ecr-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "build.apprunner.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_iam_role" "apprunner_instance" {
  name = "${local.name_prefix}-service-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "tasks.apprunner.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "apprunner_instance" {
  role = aws_iam_role.apprunner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.app_runner_secret.arn
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "app_runner_secret" {
  name = "${local.name_prefix}-app-runner-secret"
}

resource "aws_secretsmanager_secret_version" "app_runner" {
  secret_id = aws_secretsmanager_secret.app_runner_secret.id
  secret_string = jsonencode({
    OPENROUTER_API_KEY = var.openrouter_api_key
    CLERK_SECRET_KEY   = var.clerk_secret_key
  })
}

resource "aws_apprunner_service" "main" {
  service_name = "${local.name_prefix}-service"

  depends_on = [aws_secretsmanager_secret_version.app_runner]

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.app_repository.repository_url}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = "8000"

        runtime_environment_variables = {
          OPENROUTER_BASE_URL               = var.openrouter_base_url
          NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = var.next_public_clerk_publishable_key
          CLERK_JWKS_URL                    = var.clerk_jwks_url
          CLERK_SECRET_KEY                  = var.clerk_secret_key
          CLERK_JWKS_URL                    = var.clerk_jwks_url
        }
      }
    }

    auto_deployments_enabled = true
  }

  instance_configuration {
    instance_role_arn = aws_iam_role.apprunner_instance.arn
    cpu               = "1024"
    memory            = "2048"
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 3
  }
}
