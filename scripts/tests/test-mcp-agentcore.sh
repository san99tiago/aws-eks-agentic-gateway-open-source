#!/usr/bin/env bash
# MCP Gateway test 2: MCP server on Amazon Bedrock AgentCore Runtime, Cognito JWT enforced by agentgateway
source "$(dirname "$0")/../_common.sh"
set +e  # run every check; the exit code is the number of failed checks
ensure_kubeconfig
GW="${GW:-$(gateway_address)}"; [[ -z "$GW" ]] && { fail "no gateway address"; exit 1; }
PY="$REPO_ROOT/.venv/bin/python"; [[ -x "$PY" ]] || PY=python3

log "Negative test: no token -> must be rejected (401)"
code="$(curl -s -o /dev/null -w '%{http_code}' "http://$GW/agentcore/mcp" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}}}')"
[[ "$code" == "401" || "$code" == "403" ]] && ok "rejected with HTTP $code" || fail "expected 401/403, got $code"

log "Getting Cognito access token for the demo user (santigrc@amazon.com)"
TOKEN="$(cognito_access_token)"; [[ -n "$TOKEN" && "$TOKEN" != "None" ]] && ok "token acquired (${#TOKEN} chars)" || { fail "no token"; exit 1; }

log "Positive test: MCP over AgentCore Runtime with Bearer token"
"$PY" "$(dirname "$0")/mcp_client.py" "http://$GW/agentcore/mcp" --token "$TOKEN" --call agentcore_multiply '{"a": 6, "b": 7}'
"$PY" "$(dirname "$0")/mcp_client.py" "http://$GW/agentcore/mcp" --token "$TOKEN" --call agentcore_weather_demo '{"city": "Medellin"}'

RC=$FAILURES
[[ $RC -eq 0 ]] && ok "suite finished without failures" || fail "suite finished with $RC failed check(s)"
exit $RC
