################################################################################
# Amazon Bedrock AgentCore Runtime - hosts the sample MCP server
#  - protocol MCP (Streamable HTTP on :8000/mcp)
#  - Inbound auth: Cognito JWT (customJWTAuthorizer). agentgateway validates the
#    same JWT and passes it through.
################################################################################

resource "aws_bedrockagentcore_agent_runtime" "mcp" {
  agent_runtime_name = local.agentcore_runtime_name
  description        = "Sample MCP server (FastMCP) for agentgateway-santi-open, JWT auth via Cognito."
  role_arn           = aws_iam_role.agentcore.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.this["agentcore-mcp"].repository_url}:${var.image_tag}"
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "MCP"
  }

  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url   = local.cognito_discovery_url
      allowed_clients = [aws_cognito_user_pool_client.agentgateway.id]
    }
  }

  environment_variables = {
    LOG_LEVEL = "info"
  }

  tags = local.tags

  depends_on = [terraform_data.image, aws_iam_role_policy.agentcore]
}
