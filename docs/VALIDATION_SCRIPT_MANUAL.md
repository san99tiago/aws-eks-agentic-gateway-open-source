# validate_solution_scripts.sh - manual

`scripts/validate_solution_scripts.sh` is the didactic validator of the solution. Every option:

1. explains **what** is being validated and **how the request flows** through agentgateway and AWS,
2. prints the exact command (so you can copy it into your own terminal),
3. runs it and reports `OK` / `FAIL`.

```bash
./scripts/validate_solution_scripts.sh                # interactive menu
./scripts/validate_solution_scripts.sh <option> [...]  # non-interactive (numbers or names)
./scripts/validate_solution_scripts.sh --help          # built-in manual
```

It reuses the suites in `scripts/tests/` and the helpers in `scripts/_common.sh` (kubeconfig,
gateway discovery, Cognito token). Requirements: the three stacks applied, your IP allow-listed,
`aws`, `kubectl`, `jq`, `curl` and the Poetry `.venv` (for the MCP client).

## Options

| # | Option | Arguments | What it validates | Underlying flow |
| --- | --- | --- | --- | --- |
| 1 | `status` | | Nodes per NodePool (m7g general, g6.xlarge GPU), pods of all solution namespaces, Gateway address and `attachedRoutes`, models/backends/routes/policies/InferencePools | `kubectl get ...` |
| 2 | `models` | | LLM-GW discovery lists the 10 client-facing models | `GET /v1/models` (AgentgatewayModel router) |
| 3 | `llm` | | Bedrock routing on 4 models, virtual `smart` (header) and `resilient` (failover), SSE streaming, placeholder behavior | `POST /v1/chat/completions` -> Bedrock via Pod Identity |
| 4 | `chat` | `<model> "<prompt>" ["Header: value"]` | Ad-hoc completion on any model; the optional header steers virtual models | same as 3 |
| 5 | `guardrails` | | Native guardrail on Bedrock models (200 + blocked message) and ApplyGuardrail prompt guard on self-hosted/placeholders (403) | Bedrock `guardrailConfig` / `bedrock:ApplyGuardrail` |
| 6 | `guard-probe` | `<model> "<prompt>"` | One probe with HTTP code and raw body | same as 5 |
| 7 | `mcp-eks` | | Raw JSON-RPC `initialize` + FastMCP client (`eks_add`, `eks_runtime_info` -> `aarch64`) | `/mcp` -> AgentgatewayBackend(mcp) -> Service `fastmcp.mcp` |
| 8 | `mcp-agentcore` | | 401 without token, then tools through AgentCore with a Cognito access token | `/agentcore/mcp` -> jwtAuthentication -> aws.agentCore (passthrough) |
| 9 | `mcp-tool` | `<eks\|agentcore> <tool> '<json>'` | Call one tool on either MCP target | FastMCP client |
| 10 | `routing` | | Waits for model servers, one request per InferencePool model, burst of 6, EPP logs | AgentgatewayModel(Custom) -> InferencePool -> EPP -> vLLM/Ollama |
| 11 | `token` | | Prints a Cognito ACCESS token (60 min) for manual tests / MCP Inspector | `cognito-idp initiate-auth` |
| 12 | `security` | | EKS `publicAccessCidrs`, NLB SG ingress, no AWS key Secrets, Cognito sign-up disabled, AgentCore 401 without JWT | AWS CLI + kubectl |
| 13 | `secrets` | | ClusterSecretStore/ExternalSecrets `SecretSynced`, Secrets Manager placeholders | External Secrets Operator via Pod Identity |
| 14 | `logs` | `[proxy\|controller\|epp\|vllm\|ollama\|fastmcp]` | Last 30 log lines of a component (proxy = JSON access logs with `llm.*` fields) | `kubectl logs` |
| 15 | `ui` | | Port-forward instructions for the read-only agentgateway UI | `:15000/ui/` |
| 16 | `all` | | Runs 1, 2, 3, 5, 7, 8, 10, 12, 13 and prints a summary | |

## Environment variables

| Variable | Purpose |
| --- | --- |
| `GW` | NLB hostname to target (skips discovery), e.g. `GW=agentgateway-santi-open-nlb-xxxx.elb.us-east-1.amazonaws.com` |
| `COGNITO_DEMO_PASSWORD` | Demo user password (fallbacks: `TF_VAR_cognito_demo_user_password`, then `terraform/platform/secrets.auto.tfvars`) |
| `AWS_REGION` | Region (default from stack 1 outputs, `us-east-1`) |

## Worked examples

```bash
# Where is everything?
./scripts/validate_solution_scripts.sh status

# Which models can I call?
./scripts/validate_solution_scripts.sh models

# Talk to Claude Sonnet 4.5 through the gateway
./scripts/validate_solution_scripts.sh chat claude-sonnet-4-5 "Explain agentgateway in one sentence"

# Same request routed by the 'smart' virtual model: premium tier -> Claude, default -> GPT-6 Luna
./scripts/validate_solution_scripts.sh chat smart "Which model are you?" "x-model-tier: premium"
./scripts/validate_solution_scripts.sh chat smart "Which model are you?"

# See a guardrail block on a self-hosted model (HTTP 403 from the prompt guard)
./scripts/validate_solution_scripts.sh guard-probe gemma-3-4b-it "My email is test@example.com"

# Call MCP tools on both targets
./scripts/validate_solution_scripts.sh mcp-tool eks eks_runtime_info '{}'
./scripts/validate_solution_scripts.sh mcp-tool agentcore agentcore_weather_demo '{"city": "Bogota"}'

# Get a token for MCP Inspector (Streamable HTTP, header Authorization: Bearer <token>)
./scripts/validate_solution_scripts.sh token

# Full report
./scripts/validate_solution_scripts.sh all
```

## Reading the results

- Bedrock-native guardrail blocks come back as **HTTP 200** with `finish_reason: content_filter` and
  the guardrail message as the assistant content (that is how Bedrock reports it).
- Prompt-guard (ApplyGuardrail) blocks come back as **HTTP 403** with the plain-text message
  `[agentgateway-santi-open] Request blocked by Amazon Bedrock Guardrails (prompt guard).`
- `gpt-5.5` / `gemini-2.5-flash` answer `invalid_api_key` until the real keys are set
  (see [MANUAL_STEPS.md](../MANUAL_STEPS.md)); a PII prompt to them is still blocked with 403
  **before** any external call.
- `Session termination failed: 202/404` printed by the FastMCP client is harmless: the stateless
  servers do not implement `DELETE` for sessions.
- The Ollama EPP logs `Request latency values are invalid for TPOT calculation` because Ollama does
  not expose vLLM metrics; routing still works.
