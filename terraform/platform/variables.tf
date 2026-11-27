variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  description = "Naming standard applied to every resource."
  type        = string
  default     = "agentgateway-santi-open"
}

# ---------------- Cognito (JWT auth for the AgentCore MCP server) ----------------
variable "cognito_demo_user_email" {
  description = "Demo user created in the Cognito user pool (self sign-up is DISABLED)."
  type        = string
  default     = "santigrc@amazon.com"
}

variable "cognito_demo_user_password" {
  description = <<-EOT
    Permanent password of the Cognito demo user. Never committed: provide it via
    TF_VAR_cognito_demo_user_password or a git-ignored terraform/platform/secrets.auto.tfvars
    (see MANUAL_STEPS.md). Must satisfy the pool policy (>=10 chars, upper, lower, number, symbol).
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cognito_demo_user_password) >= 10
    error_message = "cognito_demo_user_password must be at least 10 characters (Cognito password policy)."
  }
}

# ---------------- Bedrock Guardrail ----------------
variable "guardrail_blocked_input_message" {
  type    = string
  default = "[agentgateway-santi-open guardrail] Your request was blocked by Amazon Bedrock Guardrails (input policy)."
}

variable "guardrail_blocked_output_message" {
  type    = string
  default = "[agentgateway-santi-open guardrail] The model response was blocked by Amazon Bedrock Guardrails (output policy)."
}

variable "guardrail_content_strength" {
  description = "Strength of HATE/INSULTS/SEXUAL/VIOLENCE filters (NONE, LOW, MEDIUM, HIGH). HIGH blocks LOW-confidence matches."
  type        = string
  default     = "MEDIUM"
  validation {
    condition     = contains(["NONE", "LOW", "MEDIUM", "HIGH"], var.guardrail_content_strength)
    error_message = "Must be one of NONE, LOW, MEDIUM, HIGH."
  }
}

variable "guardrail_misconduct_strength" {
  description = "Strength of the MISCONDUCT filter. LOW so banking chat about theft/fraud/blocking cards is not blocked."
  type        = string
  default     = "LOW"
  validation {
    condition     = contains(["NONE", "LOW", "MEDIUM", "HIGH"], var.guardrail_misconduct_strength)
    error_message = "Must be one of NONE, LOW, MEDIUM, HIGH."
  }
}

variable "guardrail_prompt_attack_strength" {
  description = "Strength of the PROMPT_ATTACK filter (inputs only)."
  type        = string
  default     = "MEDIUM"
  validation {
    condition     = contains(["NONE", "LOW", "MEDIUM", "HIGH"], var.guardrail_prompt_attack_strength)
    error_message = "Must be one of NONE, LOW, MEDIUM, HIGH."
  }
}

# ---------------- Container images ----------------
variable "image_tag" {
  description = "Tag pushed to ECR for both sample MCP servers."
  type        = string
  default     = "v1"
}

variable "build_images" {
  description = "Build and push the MCP server images with docker buildx during apply (requires a running Docker daemon)."
  type        = bool
  default     = true
}

# ---------------- Kubernetes identities that receive AWS permissions ----------------
variable "gateway_namespace" {
  description = "Namespace where the agentgateway proxy runs."
  type        = string
  default     = "agentgateway-system"
}

variable "gateway_service_account" {
  description = "ServiceAccount of the agentgateway proxy (equals the Gateway name)."
  type        = string
  default     = "agentgateway-proxy"
}

variable "eso_namespace" {
  type    = string
  default = "external-secrets"
}

variable "eso_service_account" {
  type    = string
  default = "external-secrets"
}

variable "tags" {
  type    = map(string)
  default = {}
}
