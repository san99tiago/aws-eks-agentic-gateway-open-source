#!/usr/bin/env bash
# Shared helpers for agentgateway-santi-open scripts. Source this file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_K8S="$REPO_ROOT/terraform/kubernetes"
TF_PLATFORM="$REPO_ROOT/terraform/platform"
TF_AGW="$REPO_ROOT/terraform/agentgateway"
export AWS_REGION="${AWS_REGION:-$(terraform -chdir="$TF_K8S" output -raw aws_region 2>/dev/null || echo us-east-1)}"
export AWS_PAGER=""

log()  { printf "\033[1;34m[%s]\033[0m %s\n" "$(date +%H:%M:%S)" "$*"; }
ok()   { printf "\033[1;32m  OK \033[0m %s\n" "$*"; }
FAILURES=0
fail() { printf "\033[1;31m FAIL\033[0m %s\n" "$*"; FAILURES=$((FAILURES+1)); }
warn() { printf "\033[1;33m WARN\033[0m %s\n" "$*"; }

tf_out() { # tf_out <stack-dir> <output-name>
  terraform -chdir="$1" output -raw "$2" 2>/dev/null
}

ensure_kubeconfig() {
  local cluster
  cluster="$(tf_out "$TF_K8S" cluster_name)"
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$cluster" >/dev/null
}

gateway_address() {
  kubectl get gateway agentgateway-proxy -n agentgateway-system -o jsonpath='{.status.addresses[0].value}' 2>/dev/null
}

# Waits until the NLB hostname resolves and answers HTTP (DNS propagation of a new NLB takes a few minutes)
wait_gateway_ready() {
  local addr
  for _ in $(seq 1 60); do
    addr="$(gateway_address || true)"
    if [[ -n "$addr" ]] && curl -s -o /dev/null --max-time 5 "http://$addr/v1/models"; then
      echo "$addr"; return 0
    fi
    sleep 10
  done
  return 1
}

cognito_access_token() { # prints a Cognito ACCESS token for the demo user
  local client_id pool_user pass
  client_id="$(tf_out "$TF_PLATFORM" cognito_app_client_id)"
  pool_user="$(tf_out "$TF_PLATFORM" cognito_demo_user_email)"
  pass="${COGNITO_DEMO_PASSWORD:-${TF_VAR_cognito_demo_user_password:-}}"
  if [[ -z "$pass" && -f "$TF_PLATFORM/secrets.auto.tfvars" ]]; then
    pass="$(sed -nE 's/^[[:space:]]*cognito_demo_user_password[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$TF_PLATFORM/secrets.auto.tfvars")"
  fi
  [[ -z "$pass" ]] && { fail "demo password not found: export COGNITO_DEMO_PASSWORD or create terraform/platform/secrets.auto.tfvars"; return 1; }
  aws cognito-idp initiate-auth --region "$AWS_REGION" \
    --auth-flow USER_PASSWORD_AUTH --client-id "$client_id" \
    --auth-parameters "USERNAME=$pool_user,PASSWORD=$pass" \
    --query 'AuthenticationResult.AccessToken' --output text
}
