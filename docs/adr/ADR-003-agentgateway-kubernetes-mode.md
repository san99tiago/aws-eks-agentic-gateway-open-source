# ADR-003: agentgateway in Kubernetes mode with the model-centric AgentgatewayModel API

- Status: Accepted
- Date: 2026-09-27

## Context

agentgateway (v1.5.0) can run standalone (flat YAML) or in Kubernetes mode, where a controller
translates Gateway API objects plus its own CRDs (`AgentgatewayBackend`, `AgentgatewayPolicy`,
`AgentgatewayParameters`, `AgentgatewayModel`) into proxy configuration. The LLM gateway can be
modelled route-centric (one `HTTPRoute` + `AgentgatewayBackend` per provider) or model-centric
(`AgentgatewayModel`, experimental in 1.5.x).

## Decision

- Install with the official OCI charts `cr.agentgateway.dev/charts/agentgateway-crds` and
  `.../agentgateway` **v1.5.0**, with `agentgatewayModels.enabled=true` and
  `inferenceExtension.enabled=true`.
- One `Gateway` (`agentgateway-proxy`, class `agentgateway`) with a single HTTP listener that
  allows both `HTTPRoute` and `AgentgatewayModel` kinds. This gives:
  - **LLM-GW**: unified `/v1/chat/completions` + `/v1/models`, per-model routing and policies,
    virtual models (conditional/failover).
  - **MCP-GW**: `HTTPRoute /mcp` -> `AgentgatewayBackend` (mcp targets) and
    `HTTPRoute /agentcore/mcp` -> `AgentgatewayBackend` (aws.agentCore).
- Everything is declared in a single local chart `terraform/agentgateway/charts/agentgateway-config`
  driven by values from Terraform (guardrail id, ARNs, Cognito ids, CIDRs).

## Consequences

- `AgentgatewayModel` is experimental: it does not report `status` yet, so verification uses
  `/v1/models` and gateway logs (documented in TESTING_INSTRUCTIONS.md).
- An `AgentgatewayPolicy` cannot target a model; per-model guardrails are set inline
  (`spec.policies.promptGuard` / `spec.bedrock.guardrail`).
- Fallback path (documented, not deployed): route-centric `AgentgatewayBackend` + `HTTPRoute`
  per provider if the experimental API regresses.
