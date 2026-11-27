# ADR-014: LLM model catalog - Bedrock inference profiles, virtual models, provider placeholders

- Status: Accepted (amended 2026-11-26: Amazon Nova Pro/Lite replaced by OpenAI GPT-6 Sol/Luna)
- Date: 2026-09-27

## Decision

| Client model name | Type | Target |
| --- | --- | --- |
| `claude-sonnet-4-5` | Bedrock | `us.anthropic.claude-sonnet-4-5-20250929-v1:0` (US cross-region profile) |
| `claude-haiku-4-5` | Bedrock | `global.anthropic.claude-haiku-4-5-20251001-v1:0` (global profile) |
| `gpt-6-luna` | Bedrock (OpenAI, economical tier) | `us.openai.gpt-6-luna` (US cross-region profile), `dropParams: [temperature, top_p]` |
| `gpt-6-sol` | Bedrock (OpenAI, premium tier) | `us.openai.gpt-6-sol` (US cross-region profile), `dropParams: [temperature, top_p]` |
| `smart` | virtual (conditional) | header `x-model-tier: premium` -> `claude-sonnet-4-5`, otherwise `gpt-6-luna` |
| `resilient` | virtual (failover) | `claude-sonnet-4-5` (p0) -> `gpt-6-sol` (p1), eviction after 2 consecutive 5xx |
| `gpt-5.5` | OpenAI placeholder | key from Secrets Manager |
| `gemini-2.5-flash` | Gemini placeholder | key from Secrets Manager |
| `gemma-3-4b-it` | InferencePool `gemma` | vLLM on g6.xlarge |
| `llama3.2` | InferencePool `ollama` | Ollama on g6.xlarge (`llama3.2:3b`) |

Only Bedrock **inference profiles** (`us.`/`global.` prefixes) are used for Bedrock, as requested,
which gives cross-region capacity and the newest models. Names are stable client-facing aliases:
swapping the underlying model is a one-line change in `terraform/agentgateway/terraform.tfvars`
(variable `bedrock_models`).

## Amendment 2026-11-26: OpenAI GPT-6 Luna and Sol instead of Amazon Nova

- `nova-lite` -> `gpt-6-luna` and `nova-pro` -> `gpt-6-sol`. In the AWS Price List (us-east-1) Luna is
  about 20x cheaper than Sol (prompt cache write: 0.125 vs 2.50 USD per 1M tokens on the global profile),
  so Luna keeps the "economical default" role in `smart` and Sol the "capable fallback" role in `resilient`. Both are served by Bedrock (no OpenAI key, Pod Identity auth,
  native guardrail), unlike the `gpt-5.5` placeholder, which calls the OpenAI API directly.
- Both models only exist as inference profiles (`us.`/`global.`); `us.` keeps data in US regions, the
  same choice Nova had. `global.` is about 10% cheaper if residency does not matter.
- Both answer `ValidationException` when `temperature` or `topP` is present. Instead of patching every
  client, each Bedrock model entry takes an optional `dropParams` list rendered as CEL `transformations`
  that set those OpenAI fields to `null` before the OpenAI -> Converse translation. Claude entries have
  no `dropParams` and keep honoring sampling parameters.
- When GPT-6 reasons, Bedrock returns `reasoningContent.redactedContent` (encrypted reasoning) and
  agentgateway v1.5.0 answers `failed to parse response ... ReasoningContentBlock`. `openaiReasoningEffort`
  (rendered as `finalTransformations` -> `additionalModelRequestFields.reasoning.effort`) is pinned to
  `none`: with `low` the block still appears on harder prompts. Trade-off: no reasoning, so complex
  multi-step answers lose quality (GPT-6 Luna missed a loan-amortization question at `none` that it got
  right at `low`). Upgrading agentgateway to v1.6.0 (non-streaming fix) or v1.7.0 (streaming fix) allows
  raising the effort again.
- Newer GPT-6.1 Sol / GPT-6.2 Sol (and Astra) are also available; moving to them is again a one-line
  change of `modelId`.
