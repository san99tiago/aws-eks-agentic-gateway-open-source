# ADR-010: Third-party API keys via Secrets Manager placeholders + External Secrets Operator

- Status: Accepted
- Date: 2026-09-27

## Context

OpenAI and Gemini are placeholders: agentgateway needs a Kubernetes Secret with key
`Authorization`, but real keys must never be committed, printed or stored in Terraform state.

## Decision

- Terraform creates `agentgateway-santi-open/openai-api-key`, `.../gemini-api-key` and
  `.../huggingface-token` with the value `REPLACE_ME_IN_AWS_CONSOLE` and
  `lifecycle.ignore_changes = [secret_string]`.
- The real value is set manually in the AWS console (MANUAL_STEPS.md).
- External Secrets Operator 2.11.0 (Pod Identity, ADR-006) syncs them into
  `agentgateway-system/openai-secret` and `gemini-secret` every hour (`ClusterSecretStore` with
  the default credential chain).

## Consequences

- Keys never pass through the operator's terminal, git or state.
- `recovery_window_in_days = 0` allows destroy/apply cycles without name conflicts (demo only).
