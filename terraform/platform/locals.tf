data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = data.terraform_remote_state.kubernetes.outputs.cluster_name

  # AgentCore runtime names only allow [a-zA-Z][a-zA-Z0-9_]{0,47}
  agentcore_runtime_name = replace("${var.name_prefix}_mcp", "-", "_")

  cognito_issuer        = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
  cognito_jwks_url      = "${local.cognito_issuer}/.well-known/jwks.json"
  cognito_discovery_url = "${local.cognito_issuer}/.well-known/openid-configuration"

  tags = merge({
    Project     = var.name_prefix
    Environment = "open-source-demo"
    ManagedBy   = "terraform"
    Owner       = "santigrc"
    Stack       = "platform"
  }, var.tags)
}
