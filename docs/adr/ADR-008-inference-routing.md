# ADR-008: Inference routing with the Gateway API Inference Extension + llm-d Router EPP

- Status: Accepted
- Date: 2026-09-27

## Context

"Inference routing" in agentgateway means routing to self-hosted model servers through an
`InferencePool` whose Endpoint Picker (EPP) selects the best pod (queue depth, KV-cache, LoRA).
The brief requires Ollama and Gemma, both running in EKS.

## Decision

- Install the Inference Extension CRDs v1.5.0 (vendored) and enable `inferenceExtension` in the
  agentgateway control plane.
- Two model servers in namespace `inference`, one GPU node each (ADR-004):
  - **Ollama 0.34.4** serving `llama3.2:3b` (pulled at start via `postStart`), port 11434.
  - **vLLM v0.30.0** serving Gemma 3 4B IT (`--served-model-name gemma-3-4b-it`), port 8000.
- One `llm-d-router-gateway` v0.9.0 Helm release per pool (`ollama`, `gemma`) creates the
  `InferencePool` + EPP (`provider.name=none`, `httpRoute.create=false`, EPP resources trimmed).
- Clients use model names `llama3.2` and `gemma-3-4b-it`; each is an `AgentgatewayModel` with
  `provider: Custom` and `custom.backendRef` -> `InferencePool`, so LLM features (token usage,
  Bedrock prompt guard, model rewrite) still apply.

## Consequences

- vLLM exposes the metrics the EPP expects; Ollama does not expose vLLM-style metrics, so the
  Ollama EPP logs "Request latency values are invalid for TPOT calculation" and selects endpoints
  without those signals (verified working end to end; single replica anyway).
- Helm release names double as `InferencePool` names (`ollama`, `gemma`); the model-server
  releases are therefore named `ollama-server` and `gemma-server` in the same namespace.
- First boot takes 10-15 minutes (GPU node, ~10 GB vLLM image, ~8 GB weights). Terraform does
  not wait on these deployments; the test script does.
- Fallback documented: `provider: Ollama` with `baseURL` (no EPP) if an EPP misbehaves.
