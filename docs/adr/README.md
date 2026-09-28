# Architecture Decision Records (ADRs)

Every non-obvious decision in `agentgateway-santi-open` is captured here using the
[MADR](https://adr.github.io/madr/) format (Context / Decision / Consequences / Alternatives).

| ADR | Title | Status |
| --- | --- | --- |
| [ADR-001](ADR-001-eks-auto-mode.md) | Amazon EKS Auto Mode instead of managed node groups | Accepted |
| [ADR-002](ADR-002-terraform-layout.md) | Three Terraform stacks, local state, Helm as the only Kubernetes applier | Accepted |
| [ADR-003](ADR-003-agentgateway-kubernetes-mode.md) | agentgateway in Kubernetes mode (Gateway API) with the model-centric `AgentgatewayModel` API | Accepted |
| [ADR-004](ADR-004-medium-tier-instances.md) | Medium-tier instances: Graviton m7g for general workloads, g6.xlarge (L4) for inference | Accepted |
| [ADR-005](ADR-005-network-exposure-ip-allowlist.md) | Exposure: internet-facing NLB + EKS API endpoint restricted to one /32 | Accepted |
| [ADR-006](ADR-006-eks-pod-identity.md) | EKS Pod Identity (not IRSA, not static keys) for every AWS call from the cluster | Accepted |
| [ADR-007](ADR-007-bedrock-guardrails-strategy.md) | Bedrock Guardrails applied natively on Bedrock models and via ApplyGuardrail everywhere else | Accepted |
| [ADR-008](ADR-008-inference-routing.md) | Inference routing with Gateway API Inference Extension (InferencePool) + llm-d Router EPP | Accepted |
| [ADR-009](ADR-009-gemma-weights-source.md) | Gemma 3 4B weights from the ungated `unsloth/gemma-3-4b-it` mirror | Accepted |
| [ADR-010](ADR-010-secrets-management.md) | Third-party API keys: Secrets Manager placeholders + External Secrets Operator | Accepted |
| [ADR-011](ADR-011-agentcore-mcp-jwt.md) | AgentCore Runtime MCP server with Cognito JWT, validated by agentgateway and passed through | Accepted |
| [ADR-012](ADR-012-container-images.md) | arm64 images built by `docker buildx` from Terraform (`terraform_data`) into ECR | Accepted |
| [ADR-013](ADR-013-observability.md) | Observability: CloudWatch Container Insights add-on + agentgateway UI + control-plane logs | Accepted |
| [ADR-014](ADR-014-llm-model-catalog.md) | LLM model catalog: Bedrock inference profiles, virtual models, provider placeholders | Accepted |
