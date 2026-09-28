# ADR-014: LLM model catalog - Bedrock inference profiles, virtual models, provider placeholders

- Status: Accepted
- Date: 2026-09-27

## Decision

| Client model name | Type | Target |
| --- | --- | --- |
| `claude-sonnet-4-5` | Bedrock | `us.anthropic.claude-sonnet-4-5-20250929-v1:0` (US cross-region profile) |
| `claude-haiku-4-5` | Bedrock | `global.anthropic.claude-haiku-4-5-20251001-v1:0` (global profile) |
| `nova-pro` / `nova-lite` | Bedrock | `us.amazon.nova-pro-v1:0` / `us.amazon.nova-lite-v1:0` |
| `smart` | virtual (conditional) | header `x-model-tier: premium` -> `claude-sonnet-4-5`, otherwise `nova-lite` |
| `resilient` | virtual (failover) | `claude-sonnet-4-5` (p0) -> `nova-pro` (p1), eviction after 2 consecutive 5xx |
| `gpt-5.5` | OpenAI placeholder | key from Secrets Manager |
| `gemini-2.5-flash` | Gemini placeholder | key from Secrets Manager |
| `gemma-3-4b-it` | InferencePool `gemma` | vLLM on g6.xlarge |
| `llama3.2` | InferencePool `ollama` | Ollama on g6.xlarge (`llama3.2:3b`) |

Only Bedrock **inference profiles** (`us.`/`global.` prefixes) are used for Bedrock, as requested,
which gives cross-region capacity and the newest models. Names are stable client-facing aliases:
swapping the underlying model is a one-line change in `terraform/agentgateway/terraform.tfvars`.
