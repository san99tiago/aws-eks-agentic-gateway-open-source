# ADR-006: EKS Pod Identity for every AWS call from the cluster

- Status: Accepted
- Date: 2026-09-27

## Context

The agentgateway proxy must call Bedrock (InvokeModel/Converse), Bedrock Guardrails
(ApplyGuardrail) and AgentCore (InvokeAgentRuntime). External Secrets must read Secrets Manager.
The agentgateway docs show static AWS keys in a Kubernetes Secret, which violates our security bar.

## Decision

- Create one IAM role per workload with the `pods.eks.amazonaws.com` trust policy and attach it
  with `aws_eks_pod_identity_association` to the exact `namespace/serviceaccount`:
  - `agentgateway-santi-open-gateway-role` -> `agentgateway-system/agentgateway-proxy`
    (the proxy ServiceAccount is named after the Gateway).
  - `agentgateway-santi-open-external-secrets-role` -> `external-secrets/external-secrets`.
- agentgateway resources omit `auth` (Bedrock models) or set `aws: {}` (prompt guard) so the
  Rust AWS SDK default credential chain resolves to the Pod Identity container credentials.
- Least privilege: Bedrock actions on `foundation-model/*` and account inference profiles,
  `ApplyGuardrail` on the single guardrail ARN, `InvokeAgentRuntime` on the single runtime ARN.

## Consequences

- No AWS keys in Kubernetes, Terraform state or Secrets Manager for cluster workloads.
- Auto Mode ships the Pod Identity agent, no add-on needed.
- IRSA (OIDC) remains available as fallback: the module still creates the OIDC provider.
