# ADR-002: Three Terraform stacks, S3 remote state, Helm as the only Kubernetes applier

- Status: Accepted
- Date: 2026-09-27

## Context

Terraform cannot plan `kubernetes_manifest` resources against a cluster that does not exist yet,
and the AgentCore Runtime needs a container image that must exist in ECR before creation.
The brief also requires that everything be created and destroyed easily.

## Decision

Split the solution into three root modules applied in order (`scripts/deploy-all.sh`):

| Stack | Path | Creates | Depends on |
| --- | --- | --- | --- |
| 1 kubernetes | `terraform/kubernetes` | VPC, EKS Auto Mode, NodeClasses/NodePools, add-ons | - |
| 2 platform | `terraform/platform` | Cognito, Bedrock Guardrail, Secrets Manager, ECR + images, IAM + Pod Identity, AgentCore Runtime | 1 (cluster name) |
| 3 agentgateway | `terraform/agentgateway` | CRDs, agentgateway control plane, ESO, inference stack, MCP server, gateway config | 1, 2 (`terraform_remote_state`) |

Rules:

- **All Kubernetes objects are applied with the Helm provider** (OCI charts or small local
  charts). Helm only talks to the API server at apply time, so plans never need a live cluster.
  Raw upstream manifests (Gateway API CRDs, Inference Extension CRDs) are vendored as local charts.
- **Remote state in S3** (bucket `terraform-santigrc-430118815432`, us-east-1, private, versioned,
  SSE-AES256) with one key per stack: `agentgateway-santi-open/<stack>/terraform.tfstate`. Locking uses
  the native S3 lock file (`use_lockfile = true`, Terraform >= 1.10), so no DynamoDB table is needed.
  Stacks 2 and 3 read upstream outputs with `terraform_remote_state` against the same bucket/keys.
  (History: the first deployment on 2026-09-27 used local state and was migrated the same day with
  `terraform init -migrate-state`.)
- Non-secret inputs live in committed `terraform.tfvars`; the Cognito demo password is a
  `sensitive` variable **without default**, supplied through `TF_VAR_cognito_demo_user_password` or the
  git-ignored `secrets.auto.tfvars` (an `.example` file is committed).

## Consequences

- `terraform destroy` in reverse order tears everything down (`scripts/destroy-all.sh` also waits
  for the NLB to disappear before deleting the VPC).
- Cross-stack values flow through outputs; no hardcoded IDs anywhere.
- Requires Terraform >= 1.10 (installed from the `hashicorp/tap`; the Homebrew core formula is frozen at 1.5.7).
- Helm release size limit (1 MiB compressed) is respected: the Gateway API CRD bundle compresses well.
