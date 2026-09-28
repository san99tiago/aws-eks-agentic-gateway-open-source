# ---------------- Cognito ----------------
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.agentgateway.id
}

output "cognito_issuer" {
  value = local.cognito_issuer
}

output "cognito_jwks_url" {
  value = local.cognito_jwks_url
}

output "cognito_discovery_url" {
  value = local.cognito_discovery_url
}

output "cognito_demo_user_email" {
  value = var.cognito_demo_user_email
}

# ---------------- Bedrock Guardrail ----------------
output "guardrail_id" {
  value = aws_bedrock_guardrail.this.guardrail_id
}

output "guardrail_arn" {
  value = aws_bedrock_guardrail.this.guardrail_arn
}

output "guardrail_version" {
  value = aws_bedrock_guardrail_version.this.version
}

# ---------------- Secrets Manager ----------------
output "secret_names" {
  value = { for k, v in aws_secretsmanager_secret.llm_api_keys : k => v.name }
}

# ---------------- ECR ----------------
output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "image_tag" {
  value = var.image_tag
}

# ---------------- AgentCore ----------------
output "agentcore_runtime_arn" {
  value = aws_bedrockagentcore_agent_runtime.mcp.agent_runtime_arn
}

output "agentcore_runtime_id" {
  value = aws_bedrockagentcore_agent_runtime.mcp.agent_runtime_id
}

# ---------------- IAM ----------------
output "gateway_role_arn" {
  value = aws_iam_role.gateway.arn
}

output "eso_role_arn" {
  value = aws_iam_role.eso.arn
}

output "agentcore_role_arn" {
  value = aws_iam_role.agentcore.arn
}

output "aws_region" {
  value = var.aws_region
}

output "name_prefix" {
  value = var.name_prefix
}
