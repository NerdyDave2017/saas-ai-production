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

export TF_IN_AUTOMATION=true
export TF_INPUT=false

cd "$TF_DIR"
terraform init -input=false -reconfigure
terraform destroy -auto-approve

echo ""
echo "Destroy finished for ${PROJECT_NAME} (${ENVIRONMENT})."
