# Bootstrap: GitHub Actions OIDC → IAM role for this repository’s deploy/destroy workflows.
#
# Apply once from this directory (separate state from ../ so no app secrets are required):
#   cd terraform/bootstrap-github-oidc
#   terraform init
#   terraform apply -var="github_repository=YOUR_ORG/YOUR_REPO" -var="aws_region=us-east-1"
#
# If the GitHub OIDC provider already exists (typical), existing_github_oidc.tf looks it up;
# this stack only creates the IAM role and policies.
#
# After apply, set GitHub repository secret AWS_ROLE_ARN to the output role ARN.
# When finished, delete this directory or remove the stack with terraform destroy here.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "Region used by deploy workflows (ECR, App Runner, Secrets Manager)."
  default     = "us-east-1"
}

variable "github_repository" {
  type        = string
  description = "Repository allowed to assume the role (format: owner/repo). Use the slug from the repo URL; trust matches both this value and an all-lowercase variant for GitHub’s sub claim."
}

variable "github_oidc_subject_claim" {
  type        = string
  description = "Restrict which GitHub Actions subjects may assume the role. Default allows all refs and environments for this repo."
  default     = "" # set to e.g. repo:org/repo:ref:refs/heads/main to lock to main only
}

variable "role_name" {
  type        = string
  description = "IAM role name created for GitHub Actions."
  default     = "github-actions-saas-ai-deploy"
}

variable "terraform_state_bucket" {
  type        = string
  description = "S3 bucket used by the app stack for Terraform state (same as GitHub TF_STATE_BUCKET). When set, the deploy role can read/write state objects."
  default     = ""
}

variable "terraform_state_lock_table" {
  type        = string
  description = "DynamoDB table used for Terraform state locking (same as TF_STATE_LOCK_TABLE). Optional."
  default     = ""
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # GitHub’s `sub` is case-sensitive in IAM. Allow both the configured slug and an all-lowercase form.
  oidc_sub_patterns = trimspace(var.github_oidc_subject_claim) != "" ? [
    trimspace(var.github_oidc_subject_claim),
  ] : distinct(compact([
    "repo:${var.github_repository}:*",
    "repo:${lower(var.github_repository)}:*",
  ]))
}

resource "aws_iam_role" "github_actions" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.oidc_sub_patterns
          }
        }
      },
    ]
  })

  tags = {
    Name        = "GitHub Actions deploy role"
    Repository  = var.github_repository
    ManagedBy   = "terraform"
    Purpose     = "bootstrap-github-oidc"
  }
}

resource "aws_iam_role_policy_attachment" "github_apprunner" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppRunnerFullAccess"
}

resource "aws_iam_role_policy_attachment" "github_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# PowerUser deliberately excludes CreateRepository / DeleteRepository. Terraform needs both.
resource "aws_iam_role_policy" "github_ecr_repository" {
  name = "${var.role_name}-ecr-repository"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EcrRepositoryLifecycle"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:DescribeRepositories",
          "ecr:PutLifecyclePolicy",
          "ecr:GetLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:PutImageScanningConfiguration",
          "ecr:GetImageScanningConfiguration",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:ListTagsForResource",
          "ecr:SetRepositoryPolicy",
          "ecr:GetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_secretsmanager" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "github_iam_read" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_tf_state_backend" {
  count = trimspace(var.terraform_state_bucket) != "" ? 1 : 0
  name  = "${var.role_name}-tf-state-backend"
  role  = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "TerraformStateS3"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
          ]
          Resource = [
            "arn:aws:s3:::${trimspace(var.terraform_state_bucket)}",
            "arn:aws:s3:::${trimspace(var.terraform_state_bucket)}/*",
          ]
        },
      ],
      trimspace(var.terraform_state_lock_table) != "" ? [
        {
          Sid    = "TerraformStateLockDynamoDB"
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
          ]
          Resource = [
            "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${trimspace(var.terraform_state_lock_table)}",
          ]
        },
      ] : [],
    )
  })
}

resource "aws_iam_role_policy" "github_terraform_app" {
  name = "${var.role_name}-terraform-app-resources"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StsCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
        ]
        Resource = "*"
      },
      {
        Sid    = "IamRoleManagementForTerraform"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/*"
      },
      {
        Sid    = "PassRoleToAppRunnerPrincipals"
        Effect = "Allow"
        Action = [
          "iam:PassRole",
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "iam:PassedToService" = [
              "build.apprunner.amazonaws.com",
              "tasks.apprunner.amazonaws.com",
            ]
          }
        }
      },
    ]
  })
}

output "github_actions_role_arn" {
  description = "Set this value as the AWS_ROLE_ARN secret in GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "configure_aws_credentials_snippet" {
  description = "Values for aws-actions/configure-aws-credentials in deploy.yml / destroy.yml."
  value = {
    role_to_assume   = aws_iam_role.github_actions.arn
    suggested_region = var.aws_region
  }
}
