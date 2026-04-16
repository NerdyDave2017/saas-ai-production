variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "openrouter_base_url" {
  description = "OpenRouter API base URL."
  type        = string
  default     = "https://openrouter.ai/api/v1"
}

variable "next_public_clerk_publishable_key" {
  description = "Clerk publishable key (public; safe in GitHub Actions vars)."
  type        = string
  default     = ""
}



# --- Secrets (set via TF_VAR in CI or gitignored terraform.tfvars; never commit values) ---

variable "openrouter_api_key" {
  description = "OpenRouter API key. Pass from GitHub Actions: secrets.OPENROUTER_API_KEY -> TF_VAR_openrouter_api_key"
  type        = string
  sensitive   = true
}

variable "clerk_secret_key" {
  description = "Clerk secret key. Pass from GitHub Actions: secrets.CLERK_SECRET_KEY -> TF_VAR_clerk_secret_key"
  type        = string
  sensitive   = true
}

variable "clerk_jwks_url" {
  description = "Clerk JWKS URL for JWT verification."
  type        = string
  default     = ""
}
