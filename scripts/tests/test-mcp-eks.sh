#!/usr/bin/env bash
# MCP Gateway test 1: FastMCP server running in EKS, federated by agentgateway at /mcp
source "$(dirname "$0")/../_common.sh"
set +e  # run every check; the exit code is the number of failed checks
ensure_kubeconfig
GW="${GW:-$(gateway_address)}"; [[ -z "$GW" ]] && { fail "no gateway address"; exit 1; }
PY="$REPO_ROOT/.venv/bin/python"; [[ -x "$PY" ]] || PY=python3

log "MCP initialize + tools/list via raw JSON-RPC (Streamable HTTP)"
curl -s -D - "http://$GW/mcp" -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}}}' | head -c 900; echo

log "MCP client (FastMCP): list tools and call eks_add / eks_runtime_info"
"$PY" "$(dirname "$0")/mcp_client.py" "http://$GW/mcp" --call eks_add '{"a": 40, "b": 2}'
"$PY" "$(dirname "$0")/mcp_client.py" "http://$GW/mcp" --call eks_runtime_info '{}'

RC=$FAILURES
[[ $RC -eq 0 ]] && ok "suite finished without failures" || fail "suite finished with $RC failed check(s)"
exit $RC
