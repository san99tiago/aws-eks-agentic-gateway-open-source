#!/usr/bin/env bash
# Runs the Postman collection headless with Newman against the live gateway: every pm.test of the
# 65 requests is an assertion (LLM-GW, guardrails, inference routing, MCP on EKS, AgentCore + Cognito).
#
# Usage:
#   ./scripts/tests/test-postman.sh                                   # folders 00-08
#   WITH_OBSERVABILITY=1 ./scripts/tests/test-postman.sh              # + 09 OBS (opens a kubectl port-forward)
#   POSTMAN_FOLDERS="07 · MCP-GW · FastMCP on EKS (MCP)" ./scripts/tests/test-postman.sh   # comma-separated folder names
#   POSTMAN_REPORT=postman/.newman/report.json ./scripts/tests/test-postman.sh             # keep the Newman JSON report
#
# The demo password comes from COGNITO_DEMO_PASSWORD, TF_VAR_cognito_demo_user_password or
# terraform/platform/secrets.auto.tfvars and only lives in a private temp file during the run.
# A kept JSON report contains Cognito tokens: it is git-ignored under postman/.newman/, delete it when done.
source "$(dirname "$0")/../_common.sh"
set +e

NEWMAN_VERSION="${NEWMAN_VERSION:-6.2.3}"
COLLECTION="$REPO_ROOT/postman/agentgateway-santi-open.postman_collection.json"
LOCAL_ENV="$REPO_ROOT/postman/agentgateway-santi-open.local.postman_environment.json"
command -v npx >/dev/null || { fail "npx not found: install Node.js (brew install node)"; exit 1; }

"$REPO_ROOT/scripts/postman-env.sh" >/dev/null || exit 1

PASS="${COGNITO_DEMO_PASSWORD:-${TF_VAR_cognito_demo_user_password:-}}"
if [[ -z "$PASS" && -f "$TF_PLATFORM/secrets.auto.tfvars" ]]; then
  PASS="$(sed -nE 's/^[[:space:]]*cognito_demo_user_password[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$TF_PLATFORM/secrets.auto.tfvars")"
fi
[[ -z "$PASS" ]] && warn "demo password not found: ACR-01 (Cognito login) and the AgentCore positive tests will fail"

WORK="$(mktemp -d)"; chmod 700 "$WORK"
PF=""
cleanup() { rm -rf "$WORK"; [[ -n "$PF" ]] && kill "$PF" 2>/dev/null; }
trap cleanup EXIT INT TERM
(umask 077; jq --arg p "$PASS" '.values |= map(if .key == "cognitoPassword" then .value = $p else . end)' "$LOCAL_ENV" > "$WORK/env.json")
unset PASS

FOLDER_ARGS=()
if [[ -n "${POSTMAN_FOLDERS:-}" ]]; then
  IFS=',' read -ra SELECTED <<< "$POSTMAN_FOLDERS"
  for f in "${SELECTED[@]}"; do FOLDER_ARGS+=(--folder "$f"); done
else
  while IFS= read -r f; do
    [[ "$f" == 09* && "${WITH_OBSERVABILITY:-0}" != "1" ]] && continue
    FOLDER_ARGS+=(--folder "$f")
  done < <(jq -r '.item[].name' "$COLLECTION")
fi

if [[ "${WITH_OBSERVABILITY:-0}" == "1" ]]; then
  ensure_kubeconfig
  kubectl port-forward deploy/agentgateway-proxy -n agentgateway-system 15000:15000 15020:15020 >/dev/null 2>&1 &
  PF=$!
  for _ in $(seq 1 20); do curl -s -o /dev/null --max-time 2 http://localhost:15000/ui/ && break; sleep 0.5; done
fi

REPORT="${POSTMAN_REPORT:-$WORK/report.json}"
mkdir -p "$(dirname "$REPORT")"
log "Newman $NEWMAN_VERSION -> $(jq -r '.values[] | select(.key=="baseUrl") | .value' "$LOCAL_ENV") (${#FOLDER_ARGS[@]} args)"
npx --yes "newman@$NEWMAN_VERSION" run "$COLLECTION" -e "$WORK/env.json" "${FOLDER_ARGS[@]}" \
  --timeout-request 180000 --reporters cli,json --reporter-json-export "$REPORT" --color on
RC=$?

[[ -n "${POSTMAN_REPORT:-}" ]] && warn "kept $REPORT (contains Cognito tokens; git-ignored, delete it when done)"
[[ $RC -eq 0 ]] && ok "Postman collection: every assertion passed" || fail "Postman collection reported failures (newman exit $RC)"
exit $RC
