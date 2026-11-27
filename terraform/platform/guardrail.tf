################################################################################
# Amazon Bedrock Guardrails - applied by agentgateway on every LLM route
#  - Natively (guardrailConfig) on Bedrock models
#  - Via the ApplyGuardrail API (promptGuard) on OpenAI/Gemini/self-hosted models
################################################################################

resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.name_prefix}-guardrail"
  description               = "Guardrail for agentgateway-santi-open LLM gateway: harmful content, prompt attacks, PII, denied topics and profanity."
  blocked_input_messaging   = var.guardrail_blocked_input_message
  blocked_outputs_messaging = var.guardrail_blocked_output_message

  # Strength semantics: HIGH blocks even LOW-confidence matches, MEDIUM blocks MEDIUM+HIGH confidence,
  # LOW blocks only HIGH confidence. On Converse the native guardrail evaluates the WHOLE conversation
  # (previous assistant turns included), so HIGH everywhere blocked benign banking chat such as
  # "consultar saldo" once the history mentioned "robo/fraude" (MISCONDUCT at LOW confidence).
  content_policy_config {
    dynamic "filters_config" {
      for_each = ["HATE", "INSULTS", "SEXUAL", "VIOLENCE"]
      content {
        type            = filters_config.value
        input_strength  = var.guardrail_content_strength
        output_strength = var.guardrail_content_strength
      }
    }
    # Banking conversations legitimately mention theft, fraud, blocking cards: keep MISCONDUCT permissive.
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = var.guardrail_misconduct_strength
      output_strength = var.guardrail_misconduct_strength
    }
    # Prompt attacks (jailbreak / prompt injection) can only be evaluated on inputs
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = var.guardrail_prompt_attack_strength
      output_strength = "NONE"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "BLOCK"
    }
    # ANONYMIZE (not BLOCK): "tarjeta terminada en 4321" is a normal banking request; the digits get masked.
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "AWS_ACCESS_KEY"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "AWS_SECRET_KEY"
      action = "BLOCK"
    }
    regexes_config {
      name        = "colombian_cedula"
      description = "Colombian national ID (cedula) formatted like CC 1.234.567.890 or CC 1234567890"
      pattern     = "(?i)\\bC\\.?C\\.?\\s*[0-9]{1,3}(\\.?[0-9]{3}){2,3}\\b"
      action      = "ANONYMIZE"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "InvestmentAdvice"
      type       = "DENY"
      definition = "Personalized investment advice: recommendations to buy, sell or hold specific financial instruments, crypto assets, or how a person should allocate their money to generate returns."
      examples = [
        "Should I put my savings into Bitcoin this month?",
        "Which stocks should I buy to double my money?",
        "Is it a good moment to sell my Ecopetrol shares?",
      ]
    }
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
    words_config {
      text = "agentgateway-santi-open-forbidden-word"
    }
  }

  tags = local.tags
}

# A guardrail version is an immutable snapshot. Any change to the guardrail above replaces this resource,
# which publishes a NEW version number; stack 3 reads it from remote state and re-renders the models.
resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "Published from Terraform for agentgateway-santi-open (${var.guardrail_content_strength}/${var.guardrail_misconduct_strength}/${var.guardrail_prompt_attack_strength})"
  skip_destroy  = true # keep old versions so the gateway never points at a deleted version between applies

  lifecycle {
    replace_triggered_by = [aws_bedrock_guardrail.this]
  }
}
