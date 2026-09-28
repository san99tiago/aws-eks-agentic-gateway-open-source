# ADR-009: Gemma 3 4B weights from the ungated `unsloth/gemma-3-4b-it` mirror

- Status: Accepted (confirmed by Santi on 2026-09-27)

## Context

`google/gemma-3-4b-it` on Hugging Face is gated: it requires accepting the Gemma license and a
token available to the vLLM pod, which adds a manual step and a secret in the cluster.

## Decision

Default `gemma_model = "unsloth/gemma-3-4b-it"` (same weights redistributed under the Gemma
terms, no token). The chart supports the official repo through `hfTokenSecret` and a
Secrets Manager placeholder `agentgateway-santi-open/huggingface-token` already exists.

## Consequences

- Zero manual steps for inference routing.
- Users must still comply with the Gemma Terms of Use; noted in README.
