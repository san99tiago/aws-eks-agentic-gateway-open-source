#!/usr/bin/env bash
# =============================================================================
#  validate_solution_scripts.sh - didactic validator for agentgateway-santi-open
#
#  Runs guided checks against the deployed solution (LLM-GW, MCP-GW, Inference
#  Routing, Guardrails, security posture). Every option first explains WHAT it
#  tests and HOW the request flows, then prints the exact command and runs it.
#
#  Usage:
#    ./scripts/validate_solution_scripts.sh                 # interactive menu
#    ./scripts/validate_solution_scripts.sh <option> [args] # non-interactive
#    ./scripts/validate_solution_scripts.sh --help          # manual of options
#
#  Copyright 2026 Santiago Garcia Arango - Apache 2.0
# =============================================================================
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PY="$REPO_ROOT/.venv/bin/python"; [[ -x "$PY" ]] || PY=python3
TESTS="$REPO_ROOT/scripts/tests"
GW="${GW:-}"

# ----------------------------------------------------------------------------- ui helpers
c_title() { printf "\n\033[1;35m%s\033[0m\n" "$*"; }
c_info()  { printf "\033[0;36m  %s\033[0m\n" "$*"; }
c_cmd()   { printf "\033[0;33m  \$ %s\033[0m\n" "$*"; }
c_ok()    { printf "\033[1;32m  OK \033[0m %s\n" "$*"; }
c_fail()  { printf "\033[1;31m FAIL\033[0m %s\n" "$*"; }
hr()      { printf "%s\n" "------------------------------------------------------------------------"; }

explain() { # explain "<title>" "<line>" "<line>" ...
  c_title "$1"; shift
  for l in "$@"; do c_info "$l"; done
  hr
}

run() { # run "<command string>" -> prints and executes with bash -c
  c_cmd "$1"; bash -c "$1"; local rc=$?
  [[ $rc -eq 0 ]] && c_ok "exit code 0" || c_fail "exit code $rc"
  return $rc
}

need_gateway() {
  ensure_kubeconfig 2>/dev/null || { c_fail "cannot configure kubectl. Is stack 1 applied and your IP allow-listed?"; return 1; }
  if [[ -z "$GW" ]]; then GW="$(gateway_address)"; fi
  [[ -z "$GW" ]] && { c_fail "Gateway has no address yet (kubectl get gateway -n agentgateway-system)"; return 1; }
  export GW; c_info "Gateway: http://$GW"; return 0
}

chat_json() { # chat_json <model> <prompt> [max_tokens]
  jq -cn --arg m "$1" --arg p "$2" --argjson t "${3:-120}" '{model:$m, max_tokens:$t, messages:[{role:"user",content:$p}]}'
}

# ----------------------------------------------------------------------------- options
opt_help() {
cat <<'HELP'
validate_solution_scripts.sh - manual of options
=================================================

  #  option            arguments                      what it validates
  -- ----------------- ------------------------------ -----------------------------------------------------------
  1  status                                           Cluster, NodePools, pods, Gateway address, attached routes
  2  models                                           LLM-GW discovery: GET /v1/models (10 client-facing models)
  3  llm                                              LLM-GW full suite: Bedrock routing, virtual models, streaming
  4  chat              <model> "<prompt>" [header]    Ad-hoc chat completion through the gateway (any model)
  5  guardrails                                       Bedrock Guardrails: native (Bedrock) + ApplyGuardrail (others)
  6  guard-probe       <model> "<prompt>"             Single guardrail probe, shows HTTP code and blocked message
  7  mcp-eks                                          MCP-GW target 1: FastMCP server in EKS via /mcp
  8  mcp-agentcore                                    MCP-GW target 2: AgentCore Runtime via /agentcore/mcp + Cognito JWT
  9  mcp-tool          <eks|agentcore> <tool> '<json>' Call one MCP tool through the gateway
 10  routing                                          Inference routing: InferencePools (Ollama, Gemma/vLLM) + EPP
 11  token                                            Print a Cognito ACCESS token for the demo user
 12  security                                         IP allow-lists, NLB SG, no AWS keys in cluster, Cognito sign-up off
 13  secrets                                          External Secrets sync status (placeholders from Secrets Manager)
 14  logs              [proxy|controller|epp|vllm|ollama|fastmcp]  Tail logs of a component
 15  ui                                               How to open the agentgateway read-only UI (port-forward :15000)
 16  all                                              Run 1,2,3,5,7,8,10,12,13 in sequence (full validation report)
     help | -h | --help                               This manual

Environment:
  GW=<nlb-hostname>            Skip discovery and target this gateway address
  COGNITO_DEMO_PASSWORD=...    Override the demo user password (default in terraform/platform/variables.tf)
  AWS_REGION=us-east-1         Region of the deployment

Examples:
  ./scripts/validate_solution_scripts.sh 3
  ./scripts/validate_solution_scripts.sh chat claude-haiku-4-5 "Explain EKS Auto Mode in one sentence"
  ./scripts/validate_solution_scripts.sh chat smart "Hi" "x-model-tier: premium"
  ./scripts/validate_solution_scripts.sh guard-probe gpt-6-luna "My email is test@example.com"
  ./scripts/validate_solution_scripts.sh mcp-tool eks eks_add '{"a": 40, "b": 2}'
  ./scripts/validate_solution_scripts.sh mcp-tool agentcore agentcore_weather_demo '{"city": "Medellin"}'
HELP
}

opt_status() {
  explain "1) Status of the solution" \
    "Shows the EKS Auto Mode nodes (Graviton general pool + g6.xlarge GPU pool), the pods of every" \
    "namespace of the solution, the Gateway (NLB address, PROGRAMMED) and how many routes/models attached."
  ensure_kubeconfig || return 1
  run "kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.sh/nodepool"
  run "kubectl get pods -A --field-selector metadata.namespace!=kube-system,metadata.namespace!=amazon-cloudwatch -o wide | awk '{print \$1, \$2, \$4, \$8}' | column -t"
  run "kubectl get gateway -n agentgateway-system && kubectl get gateway agentgateway-proxy -n agentgateway-system -o jsonpath='attachedRoutes={.status.listeners[0].attachedRoutes}{\"\\n\"}'"
  run "kubectl get agentgatewaymodels -A && kubectl get agentgatewaybackends,httproutes,agentgatewaypolicies -n agentgateway-system && kubectl get inferencepool -n inference"
}

opt_models() {
  explain "2) LLM-GW model discovery" \
    "agentgateway serves an OpenAI-compatible /v1/models built from every AgentgatewayModel attached" \
    "to the listener: 4 Bedrock models, 2 virtual models, 2 placeholders and 2 InferencePool models."
  need_gateway || return 1
  run "curl -s http://$GW/v1/models | jq -r '.data[] | \"  - \\(.id)  (owned_by=\\(.owned_by))\"'"
}

opt_llm() {
  explain "3) LLM Gateway suite (Amazon Bedrock inference profiles)" \
    "Flow: client -> NLB (your IP only) -> agentgateway proxy -> AgentgatewayModel -> Bedrock (SigV4 via EKS Pod Identity)." \
    "Checks: discovery, chat on claude-sonnet-4-5 / claude-haiku-4-5 / gpt-6-luna / gpt-6-sol, temperature/top_p" \
    "dropped for GPT-6, virtual model 'smart' (header x-model-tier), virtual model 'resilient' (failover)," \
    "SSE streaming, and the placeholders."
  need_gateway || return 1
  run "bash $TESTS/test-llm-gw.sh"
}

opt_chat() {
  local model="${1:-claude-haiku-4-5}" prompt="${2:-Say hello in one sentence.}" header="${3:-}"
  explain "4) Ad-hoc chat completion" \
    "POST /v1/chat/completions with model='$model'. Bedrock models apply the guardrail natively; InferencePool" \
    "and placeholder models go through the ApplyGuardrail prompt guard first." \
    "Optional header (3rd argument) e.g. 'x-model-tier: premium' to steer the virtual model 'smart'."
  need_gateway || return 1
  local h=""; [[ -n "$header" ]] && h="-H '$header'"
  run "curl -s --max-time 180 http://$GW/v1/chat/completions -H 'content-type: application/json' $h -d '$(chat_json "$model" "$prompt")' | jq '{model, content: .choices[0].message.content, usage}'"
}

opt_guardrails() {
  explain "5) Amazon Bedrock Guardrails suite" \
    "One guardrail (agentgateway-santi-open-guardrail, latest published version): content filters MEDIUM, MISCONDUCT" \
    "LOW, prompt attacks MEDIUM, PII (email/SSN/AWS keys BLOCK; cards, phone, Colombian cedula ANONYMIZE)," \
    "denied topic InvestmentAdvice, profanity, custom word (strengths: guardrail_*_strength in platform tfvars)." \
    "Bedrock models -> guardrailConfig on the invocation (HTTP 200 with blocked message)." \
    "Self-hosted / placeholders -> agentgateway calls ApplyGuardrail before the model (HTTP 403 custom message)."
  need_gateway || return 1
  run "bash $TESTS/test-guardrails.sh"
}

opt_guard_probe() {
  local model="${1:-gpt-6-luna}" prompt="${2:-My email is santiago.test@example.com}"
  explain "6) Single guardrail probe" "Sends the prompt to '$model' and shows HTTP code + body so you can see how the block surfaces."
  need_gateway || return 1
  run "curl -s -w '\\n  HTTP %{http_code}\\n' --max-time 180 http://$GW/v1/chat/completions -H 'content-type: application/json' -d '$(chat_json "$model" "$prompt" 150)' | head -c 600"
}

opt_mcp_eks() {
  explain "7) MCP Gateway - target 1: FastMCP on EKS" \
    "Flow: MCP client -> /mcp -> AgentgatewayBackend(mcp) -> Service fastmcp.mcp.svc (appProtocol agentgateway.dev/mcp)." \
    "Checks raw JSON-RPC initialize (Streamable HTTP) and a FastMCP client calling eks_add and eks_runtime_info" \
    "(the latter proves the tool ran on a Graviton pod: arch=aarch64)."
  need_gateway || return 1
  run "bash $TESTS/test-mcp-eks.sh 2>&1 | grep -vE 'Deprecation|authlib|compatible before'"
}

opt_mcp_agentcore() {
  explain "8) MCP Gateway - target 2: Amazon Bedrock AgentCore Runtime + Cognito JWT" \
    "Flow: client (Bearer Cognito ACCESS token) -> /agentcore/mcp -> AgentgatewayPolicy jwtAuthentication (issuer," \
    "JWKS, client_id, token_use) -> AgentgatewayBackend aws.agentCore (token passthrough) -> AgentCore customJWTAuthorizer." \
    "Negative test first (no token -> 401 at the gateway), then tools/list + agentcore_multiply + agentcore_weather_demo."
  need_gateway || return 1
  run "bash $TESTS/test-mcp-agentcore.sh 2>&1 | grep -vE 'Deprecation|authlib|compatible before'"
}

opt_mcp_tool() {
  local target="${1:-eks}" tool="${2:-eks_hello}" args="${3:-{\}}"
  explain "9) Call one MCP tool through the gateway" "target=$target tool=$tool args=$args"
  need_gateway || return 1
  if [[ "$target" == "agentcore" ]]; then
    local tok; tok="$(cognito_access_token)" || { c_fail "could not get Cognito token"; return 1; }
    c_cmd "$PY $TESTS/mcp_client.py http://$GW/agentcore/mcp --token '<cognito-access-token>' --call $tool '$args'"
    "$PY" "$TESTS/mcp_client.py" "http://$GW/agentcore/mcp" --token "$tok" --call "$tool" "$args" 2>&1 | grep -vE 'Deprecation|authlib|compatible before' && c_ok "exit code 0" || c_fail "tool call failed"
  else
    run "$PY $TESTS/mcp_client.py http://$GW/mcp --call $tool '$args' 2>&1 | grep -vE 'Deprecation|authlib|compatible before'"
  fi
}

opt_routing() {
  explain "10) Inference routing (Gateway API Inference Extension)" \
    "Flow: /v1/chat/completions model=gemma-3-4b-it|llama3.2 -> AgentgatewayModel(provider Custom) -> InferencePool" \
    "-> llm-d Router EPP picks the pod (queue/KV-cache signals) -> vLLM (Gemma 3 4B) or Ollama (llama3.2:3b) on g6.xlarge." \
    "Waits for the model servers, sends one request per model, then a burst of 6 and shows EPP decisions."
  need_gateway || return 1
  run "bash $TESTS/test-inference-routing.sh"
}

opt_token() {
  explain "11) Cognito access token" "USER_PASSWORD_AUTH against the demo app client. Use it as 'Authorization: Bearer <token>' for /agentcore/mcp."
  c_cmd "aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH --client-id <app-client> --auth-parameters USERNAME=santigrc@amazon.com,PASSWORD=*** --query AuthenticationResult.AccessToken"
  local tok; tok="$(cognito_access_token)" && { c_ok "token acquired (${#tok} chars, expires in 60 min)"; echo "$tok"; } || c_fail "could not get token"
}

opt_security() {
  explain "12) Security posture" \
    "EKS API endpoint allow-list, NLB security group ingress, absence of static AWS keys in the cluster," \
    "Cognito self sign-up disabled, and AgentCore rejecting calls without JWT even when bypassing the gateway."
  ensure_kubeconfig || return 1
  run "aws eks describe-cluster --region $AWS_REGION --name $(tf_out "$TF_K8S" cluster_name) --query 'cluster.resourcesVpcConfig.publicAccessCidrs' --output json | tr -d '\\n '; echo"
  run "LB=\$(aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[?contains(DNSName,\`agentgateway-santi-open-nlb\`)].LoadBalancerArn' --output text); for SG in \$(aws elbv2 describe-load-balancers --region $AWS_REGION --load-balancer-arns \"\$LB\" --query 'LoadBalancers[0].SecurityGroups[]' --output text); do echo \"SG \$SG:\"; aws ec2 describe-security-groups --region $AWS_REGION --group-ids \$SG --query 'SecurityGroups[0].IpPermissions[].[IpProtocol,FromPort,IpRanges[].CidrIp]' --output json | tr -d '\\n '; echo; done"
  run "kubectl get secrets -A --no-headers | grep -ciE 'aws-cred|aws-secret|accesskey' || echo 'no AWS key secrets found (Pod Identity in use)'"
  run "aws cognito-idp sign-up --region $AWS_REGION --client-id $(tf_out "$TF_PLATFORM" cognito_app_client_id) --username attacker@example.com --password 'Not-A-Real-Password-1!' 2>&1 | grep -o 'SignUp is not permitted for this user pool' || echo 'UNEXPECTED: sign-up allowed'"
  run "ARN=$(tf_out "$TF_PLATFORM" agentcore_runtime_arn); ENC=\$(python3 -c \"import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))\" \"\$ARN\"); curl -s -o /dev/null -w 'AgentCore without JWT -> HTTP %{http_code}\\n' -X POST \"https://bedrock-agentcore.$AWS_REGION.amazonaws.com/runtimes/\$ENC/invocations?qualifier=DEFAULT\" -H 'content-type: application/json' -d '{}'"
}

opt_secrets() {
  explain "13) External Secrets sync" \
    "ClusterSecretStore (AWS Secrets Manager via Pod Identity) -> ExternalSecrets -> Kubernetes Secrets openai-secret/gemini-secret." \
    "Values are placeholders until MANUAL_STEPS.md is done; the sync itself must be SecretSynced/Ready."
  ensure_kubeconfig || return 1
  run "kubectl get clustersecretstore && kubectl get externalsecret -n agentgateway-system"
  run "aws secretsmanager list-secrets --region $AWS_REGION --filters Key=name,Values=agentgateway-santi-open/ --query 'SecretList[].[Name,LastChangedDate]' --output table"
}

opt_logs() {
  local comp="${1:-proxy}" sel
  case "$comp" in
    proxy)      sel="-n agentgateway-system deploy/agentgateway-proxy" ;;
    controller) sel="-n agentgateway-system deploy/agentgateway" ;;
    epp)        sel="-n inference deploy/gemma-epp" ;;
    vllm)       sel="-n inference deploy/gemma-vllm" ;;
    ollama)     sel="-n inference deploy/ollama" ;;
    fastmcp)    sel="-n mcp deploy/fastmcp -c fastmcp" ;;
    *) c_fail "unknown component '$comp' (proxy|controller|epp|vllm|ollama|fastmcp)"; return 1 ;;
  esac
  explain "14) Logs: $comp" "Last 30 lines. The proxy emits JSON access logs with llm.* fields (model, tokens) and route names."
  ensure_kubeconfig || return 1
  run "kubectl logs $sel --tail=30 | cut -c1-220"
}

opt_ui() {
  explain "15) agentgateway read-only UI" \
    "The proxy exposes a UI on port 15000 (never published). It reflects the config pushed by the controller:" \
    "listeners, routes, backends and policies. Run the port-forward in another terminal and open the URL."
  c_cmd "kubectl port-forward deploy/agentgateway-proxy -n agentgateway-system 15000:15000"
  c_info "then open: http://localhost:15000/ui/"
}

opt_all() {
  explain "16) Full validation report" "Runs the read-only status plus every functional suite. Takes ~3-5 minutes."
  local failed=0
  for o in status models llm guardrails mcp-eks mcp-agentcore routing security secrets; do
    dispatch "$o" || failed=$((failed+1))
  done
  hr; [[ $failed -eq 0 ]] && c_ok "ALL SUITES PASSED" || c_fail "$failed suite(s) reported failures"
  return $failed
}

dispatch() {
  local o="$1"; shift || true
  case "$o" in
    1|status)          opt_status ;;
    2|models)          opt_models ;;
    3|llm)             opt_llm ;;
    4|chat)            opt_chat "$@" ;;
    5|guardrails)      opt_guardrails ;;
    6|guard-probe)     opt_guard_probe "$@" ;;
    7|mcp-eks)         opt_mcp_eks ;;
    8|mcp-agentcore)   opt_mcp_agentcore ;;
    9|mcp-tool)        opt_mcp_tool "$@" ;;
    10|routing)        opt_routing ;;
    11|token)          opt_token ;;
    12|security)       opt_security ;;
    13|secrets)        opt_secrets ;;
    14|logs)           opt_logs "$@" ;;
    15|ui)             opt_ui ;;
    16|all)            opt_all ;;
    help|-h|--help)    opt_help ;;
    *) c_fail "unknown option '$o'"; opt_help; return 1 ;;
  esac
}

menu() {
  while true; do
    printf "\n\033[1;35m agentgateway-santi-open · validation menu\033[0m\n"
    cat <<'MENU'
   1) status          6) guard-probe      11) token          16) all
   2) models          7) mcp-eks          12) security        h) help (manual)
   3) llm             8) mcp-agentcore    13) secrets         q) quit
   4) chat            9) mcp-tool         14) logs
   5) guardrails     10) routing          15) ui
MENU
    read -r -p "  choose an option: " choice rest
    case "$choice" in q|quit|exit) exit 0 ;; h) opt_help ;; "") ;; *) dispatch "$choice" $rest ;; esac
  done
}

if [[ $# -eq 0 ]]; then menu; else dispatch "$@"; fi
