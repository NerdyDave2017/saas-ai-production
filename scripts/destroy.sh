#!/usr/bin/env bash
# Tear down App Runner, ECR, IAM roles, and Secrets Manager resources for this stack.
#
# Terraform destroys (in dependency order):
#   - App Runner service
#   - ECR repository (images removed when force_delete is true on the repo)
#   - Secrets Manager secret + version
#   - IAM instance role + inline policy, ECR access role + managed policy attachment
#
# Usage:
#   export AWS_REGION=us-east-1
#   export TF_VAR_openrouter_api_key=...   # same as deploy (or placeholders if you accept a no-op SM update before delete)
#   export TF_VAR_clerk_secret_key=...
#   ./scripts/destroy.sh <environment> <project_name>
#
# Example:
#   ./scripts/destroy.sh dev my-saas-app

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment: dev|test|prod> <project_name>}"
PROJECT_NAME="${2:?Usage: $0 <environment> <project_name: lowercase-hyphenated>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform"

export TF_VAR_project_name="$PROJECT_NAME"
export TF_VAR_environment="$ENVIRONMENT"

: "${AWS_REGION:?Set AWS_REGION}"
: "${TF_VAR_openrouter_api_key:?Set TF_VAR_openrouter_api_key (match deploy or CI)}"
: "${TF_VAR_clerk_secret_key:?Set TF_VAR_clerk_secret_key (match deploy or CI)}"
: "${TF_VAR_clerk_jwks_url:?Set TF_VAR_clerk_jwks_url (match deploy or CI)}"

export TF_IN_AUTOMATION=true
export TF_INPUT=false

cd "$TF_DIR"

# Get AWS Account ID and Region for backend configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:latest"

# Initialize terraform with S3 backend
echo "🔧 Initializing Terraform with S3 backend..."
terraform init -input=false \
  -backend-config="bucket=saas-ai-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=saas-ai/${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=saas-ai-terraform-locks" \
  -backend-config="encrypt=true"

# Check if workspace exists
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "❌ Error: Workspace '$ENVIRONMENT' does not exist"
    echo "Available workspaces:"
    terraform workspace list
    exit 1
fi


echo "🔥 Running terraform destroy..."

# Select the workspace
terraform workspace select "$ENVIRONMENT"

# Delete the ECR repository
aws ecr delete-repository --repository-name "${REPO_NAME}" --force  

# Run terraform destroy with auto-approve
if [ "$ENVIRONMENT" = "prod" ] && [ -f "prod.tfvars" ]; then
    terraform destroy -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
else
    terraform destroy -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
fi

echo "✅ Infrastructure for ${ENVIRONMENT} has been destroyed!"
echo ""
echo "💡 To remove the workspace completely, run:"
echo "   terraform workspace select default"
echo "   terraform workspace delete $ENVIRONMENT"
