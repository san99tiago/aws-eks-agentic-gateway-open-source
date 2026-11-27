aws_region  = "us-east-1"
name_prefix = "agentgateway-santi-open"
image_tag   = "v1"

# Cognito demo identity (self sign-up disabled). Password default lives in variables.tf (demo only).
cognito_demo_user_email = "santigrc@amazon.com"

# Bedrock Guardrail strengths (NONE, LOW, MEDIUM, HIGH). HIGH blocks even LOW-confidence matches and, on
# Converse, the whole conversation is evaluated: v1 with everything HIGH blocked benign banking chat.
guardrail_content_strength       = "MEDIUM"
guardrail_misconduct_strength    = "LOW"
guardrail_prompt_attack_strength = "MEDIUM"
