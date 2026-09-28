# ADR-007: Bedrock Guardrails natively on Bedrock models and via ApplyGuardrail everywhere else

- Status: Accepted
- Date: 2026-09-27

## Context

The guardrail must protect **all** LLM traffic: Bedrock models, third-party placeholders and
self-hosted models. agentgateway offers two integrations: `spec.bedrock.guardrail` (passes
`guardrailConfig` on the Bedrock invocation) and `policies.promptGuard.*.bedrockGuardrails`
(calls the model-agnostic ApplyGuardrail API before/after the LLM).

## Decision

- One guardrail (`agentgateway-santi-open-guardrail`, published version 1) defined in Terraform:
  content filters HIGH (hate, insults, sexual, violence, misconduct, prompt attack), PII
  (email/cards/SSN/AWS keys BLOCK, phone ANONYMIZE, Colombian cedula regex ANONYMIZE),
  denied topic "InvestmentAdvice", profanity list and a custom word.
- Bedrock models: `bedrock.guardrail` (native, no extra round trip, covers input and output).
- OpenAI/Gemini placeholders and InferencePool models: `promptGuard.request` and
  `promptGuard.response` with `bedrockGuardrails` (`action: Reject`, 403 with custom message),
  authenticated through Pod Identity (`auth.aws: {}`).

## Consequences

- Blocked prompts on placeholders are rejected **before** any external API call (and even while
  the key is still a placeholder), which is also a useful demo.
- ApplyGuardrail is billed per text unit; acceptable for the demo volume.
- Streaming responses are guarded on Bedrock natively; for prompt-guard models only requests
  and full responses are inspected (streaming guard is opt-in and not enabled).
