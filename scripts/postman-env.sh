#!/usr/bin/env bash
# Writes the git-ignored Postman environment
#   postman/agentgateway-santi-open.local.postman_environment.json
# from the live deployment (gateway NLB address + Cognito outputs of stack 2).
# The demo password is NOT written: type it in Postman (secret variable cognitoPassword), or let
# scripts/tests/test-postman.sh inject it for Newman runs.
# Usage: ./scripts/postman-env.sh
source "$(dirname "$0")/_common.sh"

TEMPLATE="$REPO_ROOT/postman/agentgateway-santi-open.postman_environment.json"
OUT="$REPO_ROOT/postman/agentgateway-santi-open.local.postman_environment.json"

ensure_kubeconfig
GW="$(gateway_address || true)"
[[ -z "$GW" ]] && { fail "gateway address not found (is stack 3 applied and the NLB provisioned?)"; exit 1; }
CID="$(tf_out "$TF_PLATFORM" cognito_app_client_id)"
DEMO_USER="$(tf_out "$TF_PLATFORM" cognito_demo_user_email)"

jq --arg gw "http://$GW" --arg cid "$CID" --arg user "$DEMO_USER" --arg region "$AWS_REGION" '
  .id = "5a0c6e1f-2b7d-4c3e-8f19-6a3b2c1d0e9f" |
  .name = "agentgateway-santi-open (local, live)" |
  .values |= map(
    if   .key == "baseUrl"         then .value = $gw
    elif .key == "cognitoClientId" then .value = $cid
    elif .key == "cognitoUsername" then .value = $user
    elif .key == "awsRegion"       then .value = $region
    else . end)' "$TEMPLATE" > "$OUT"

ok "wrote ${OUT#"$REPO_ROOT"/} (baseUrl=http://$GW)"
echo "  Import it in Postman with postman/agentgateway-santi-open.postman_collection.json, select it and fill the secret cognitoPassword."
