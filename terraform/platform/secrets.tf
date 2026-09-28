################################################################################
# AWS Secrets Manager - placeholders for third-party LLM API keys.
# Terraform creates the secret with a PLACEHOLDER value and then ignores changes
# to the value, so the real key is set manually in the console (MANUAL_STEPS.md)
# and synced into Kubernetes by External Secrets Operator (stack 3).
################################################################################

locals {
  llm_api_key_secrets = {
    openai = {
      name        = "${var.name_prefix}/openai-api-key"
      description = "OpenAI API key (PLACEHOLDER until set manually). Consumed by agentgateway via External Secrets."
    }
    gemini = {
      name        = "${var.name_prefix}/gemini-api-key"
      description = "Google Gemini API key (PLACEHOLDER until set manually). Consumed by agentgateway via External Secrets."
    }
    huggingface = {
      name        = "${var.name_prefix}/huggingface-token"
      description = "Optional Hugging Face token (only if switching Gemma to the gated official repo)."
    }
  }
}

resource "aws_secretsmanager_secret" "llm_api_keys" {
  for_each = local.llm_api_key_secrets

  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = 0 # demo environment: allow immediate re-creation on destroy/apply cycles
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "llm_api_keys" {
  for_each = aws_secretsmanager_secret.llm_api_keys

  secret_id     = each.value.id
  secret_string = "REPLACE_ME_IN_AWS_CONSOLE"

  lifecycle {
    ignore_changes = [secret_string] # keep the manually-set real value
  }
}
