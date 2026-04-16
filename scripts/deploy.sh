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
: "${TF_VAR_clerk_jwks_url:?Set TF_VAR_clerk_jwks_url}"
: "${TF_VAR_clerk_secret_key:?Set TF_VAR_clerk_secret_key}"
: "${AWS_REGION:?Set AWS_REGION}"

TF_DIR="$ROOT/terraform"
export TF_IN_AUTOMATION=true
export TF_INPUT=false

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:latest"

cd "$TF_DIR"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

terraform init -input=false \
  -backend-config="bucket=twin-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=twin-terraform-locks" \
  -backend-config="encrypt=true"

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace new "$ENVIRONMENT"
else
  terraform workspace select "$ENVIRONMENT"
fi

# Shared apply arguments (full apply and ECR-only apply must stay consistent, e.g. prod.tfvars).
TF_APPLY_ARGS=(-var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
if [ "$ENVIRONMENT" = "prod" ]; then
  TF_APPLY_ARGS=(-var-file=prod.tfvars "${TF_APPLY_ARGS[@]}")
fi

echo "==> Phase 1: Create ECR repository (Terraform -target; App Runner comes later)"
terraform apply -target=aws_ecr_repository.app_repository "${TF_APPLY_ARGS[@]}"

echo "==> Phase 2: Docker build and push to ${IMAGE_URI}"
cd "$ROOT"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build \
  --build-arg "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${TF_VAR_next_public_clerk_publishable_key:-}" \
  -t "$IMAGE_URI" \
  .

docker push "$IMAGE_URI"

echo "==> Phase 3: Apply full stack (IAM, App Runner, …) — image is already in ECR"
cd "$TF_DIR"
terraform apply "${TF_APPLY_ARGS[@]}"

SERVICE_URL="$(terraform output -raw app_runner_service_url)"
echo ""
echo "Deployment finished."
echo "App Runner URL: ${SERVICE_URL}"
