# ADR-011: AgentCore Runtime MCP server with Cognito JWT validated by agentgateway and passed through

- Status: Accepted
- Date: 2026-09-27

## Context

The second MCP target must run on Amazon Bedrock AgentCore Runtime (protocol MCP) with JWT
inbound auth from Cognito, using the demo user `santigrc@amazon.com` and no self sign-up.

## Decision

- Cognito user pool `agentgateway-santi-open-users`: `allow_admin_create_user_only`, one user with
  a permanent password (never committed; provided at apply time), public app client with
  `USER_PASSWORD_AUTH` (tests) and SRP.
- AgentCore Runtime `agentgateway_santi_open_mcp`: container (arm64) from ECR, `server_protocol =
  MCP`, `custom_jwt_authorizer` with the pool discovery URL and `allowed_clients = [app client]`.
- agentgateway route `/agentcore/mcp`:
  - `AgentgatewayPolicy` `traffic.jwtAuthentication` (Strict, Cognito issuer, remote JWKS URL,
    `preserveToken: true`) and `authorization` CEL: `jwt.client_id == <client>` and
    `jwt.token_use == "access"`.
  - `AgentgatewayBackend` `aws.agentCore.agentRuntimeArn` with `policies.auth.passthrough: {}`
    so the **same access token** is forwarded to AgentCore (which validates it again).
- The EKS MCP route (`/mcp`) stays unauthenticated on purpose (network allow-list only) to keep
  one simple target; adding the same JWT policy is a two-line change.

## Consequences

- No token stored in the cluster (the docs' `secretRef` approach would expire hourly).
- Access tokens (not ID tokens) are required: AgentCore checks `client_id`.
- Rejected requests return 401 at the gateway without reaching AWS.
