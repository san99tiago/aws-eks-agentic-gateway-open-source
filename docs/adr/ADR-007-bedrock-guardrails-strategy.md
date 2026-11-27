# ADR-007: Bedrock Guardrails natively on Bedrock models and via ApplyGuardrail everywhere else

- Status: Accepted
- Date: 2026-09-27

## Context

The guardrail must protect **all** LLM traffic: Bedrock models, third-party placeholders and
self-hosted models. agentgateway offers two integrations: `spec.bedrock.guardrail` (passes
`guardrailConfig` on the Bedrock invocation) and `policies.promptGuard.*.bedrockGuardrails`
(calls the model-agnostic ApplyGuardrail API before/after the LLM).

## Decision

- One guardrail (`agentgateway-santi-open-guardrail`) defined in Terraform, published as an immutable
  version that is re-created on every change (`replace_triggered_by`, `skip_destroy = true`); stack 3
  reads the version number from remote state. Policies: content filters MEDIUM (hate, insults, sexual,
  violence), MISCONDUCT LOW, PROMPT_ATTACK MEDIUM (inputs), PII (email/SSN/AWS keys BLOCK, cards, phone
  and Colombian cedula regex ANONYMIZE), denied topic "InvestmentAdvice", profanity list and a custom
  word. Strengths are variables (`guardrail_*_strength`) in `terraform/platform/variables.tf`.
- Bedrock models: `bedrock.guardrail` (native, no extra round trip, covers input and output).
- OpenAI/Gemini placeholders and InferencePool models: `promptGuard.request` and
  `promptGuard.response` with `bedrockGuardrails` (`action: Reject`, 403 with custom message),
  authenticated through Pod Identity (`auth.aws: {}`).

## Consequences

- **Version 1 (all filters HIGH) was too aggressive and was replaced by version 2 on 2026-09-28.** HIGH
  strength blocks even LOW-confidence matches, and on Converse the native guardrail evaluates the whole
  conversation (previous assistant turns included). Once the history mentioned "robo/fraude" (the agent
  listing what it can do), benign follow-ups such as "consultar saldo" were blocked by MISCONDUCT at LOW
  confidence. Card digits ("tarjeta terminada en 4321") were blocked outright by the card PII entity.
- The PROMPT_ATTACK classifier scores English system-prompt-like text in the input ("You are a concise
  assistant.") as HIGH confidence, so it is blocked at MEDIUM strength too. The Spanish banking system prompt
  passes alone but scores MEDIUM confidence once combined with the user turn, which the prompt guard does
  (ApplyGuardrail receives the whole message list, system prompt included). Hence agent2 has no system prompt;
  set `guardrail_prompt_attack_strength = "LOW"` to allow system prompts on self-hosted models.

- Blocked prompts on placeholders are rejected **before** any external API call (and even while
  the key is still a placeholder), which is also a useful demo.
- ApplyGuardrail is billed per text unit; acceptable for the demo volume.
- Streaming responses are guarded on Bedrock natively; for prompt-guard models only requests
  and full responses are inspected (streaming guard is opt-in and not enabled).
