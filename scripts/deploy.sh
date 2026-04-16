#!/usr/bin/env bash
# Build the app image, push to ECR, and apply Terraform for App Runner.
#
# Prerequisites: AWS CLI v2, Docker, Terraform >= 1.0, and credentials with
# ECR push + Terraform permissions (e.g. aws configure or OIDC-assumed role).
#
# Usage:
#   export TF_VAR_openrouter_api_key=...
#   export TF_VAR_clerk_secret_key=...
#   export TF_VAR_next_public_clerk_publishable_key=...
#   export AWS_REGION=us-east-1
#   ./scripts/deploy.sh <environment> <project_name>
#
# Example:
#   ./scripts/deploy.sh dev my-saas-app

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment: dev|test|prod> <project_name>}"
PROJECT_NAME="${2:?Usage: $0 <environment> <project_name: lowercase-hyphenated>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export TF_VAR_project_name="$PROJECT_NAME"
export TF_VAR_environment="$ENVIRONMENT"

: "${TF_VAR_openrouter_api_key:?Set TF_VAR_openrouter_api_key}"
: "${TF_VAR_clerk_secret_key:?Set TF_VAR_clerk_secret_key}"
: "${AWS_REGION:?Set AWS_REGION}"

TF_DIR="$ROOT/terraform"
export TF_IN_AUTOMATION=true
export TF_INPUT=false

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:latest"

echo "==> Phase 1: ECR, IAM, Secrets Manager (image not required yet)"
cd "$TF_DIR"
terraform init -input=false -reconfigure
terraform apply -auto-approve \
  -target=aws_ecr_repository.app_repository \
  -target=aws_iam_role.apprunner_ecr_access \
  -target=aws_iam_role_policy_attachment.apprunner_ecr \
  -target=aws_iam_role.apprunner_instance \
  -target=aws_iam_role_policy.apprunner_instance \
  -target=aws_secretsmanager_secret.app_runner_secret \
  -target=aws_secretsmanager_secret_version.app_runner

echo "==> Phase 2: Docker build and push to ${IMAGE_URI}"
cd "$ROOT"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build \
  --build-arg "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${TF_VAR_next_public_clerk_publishable_key:-}" \
  -t "$IMAGE_URI" \
  .

docker push "$IMAGE_URI"

echo "==> Phase 3: App Runner and remaining resources"
cd "$TF_DIR"
terraform init -input=false -reconfigure
terraform apply -auto-approve

SERVICE_URL="$(terraform output -raw app_runner_service_url)"
echo ""
echo "Deployment finished."
echo "App Runner URL: ${SERVICE_URL}"
