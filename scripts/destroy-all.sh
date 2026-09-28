#!/usr/bin/env bash
# Destroys everything in reverse order. Usage: ./scripts/destroy-all.sh [--auto-approve]
source "$(dirname "$0")/_common.sh"
APPROVE="${1:-}"

log "Stack 3/3 - agentgateway (also removes the NLB created by the Gateway)"
terraform -chdir="$TF_AGW" destroy -input=false ${APPROVE} || warn "stack 3 destroy had errors (continuing)"

log "Waiting for the NLB to be deleted before removing the VPC..."
ensure_kubeconfig 2>/dev/null || true
for _ in $(seq 1 30); do
  kubectl get svc -A -o json 2>/dev/null | jq -e '[.items[] | select(.spec.type=="LoadBalancer")] | length == 0' >/dev/null && break
  sleep 10
done

log "Stack 2/3 - platform"
terraform -chdir="$TF_PLATFORM" destroy -input=false ${APPROVE}

log "Stack 1/3 - kubernetes"
terraform -chdir="$TF_K8S" destroy -input=false ${APPROVE}
log "All resources destroyed."
