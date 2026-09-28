#!/usr/bin/env bash
# Deploys the three Terraform stacks in order. Idempotent (terraform apply).
# Usage: ./scripts/deploy-all.sh [--auto-approve]
source "$(dirname "$0")/_common.sh"
APPROVE="${1:-}"

log "Stack 1/3 - kubernetes (VPC + EKS Auto Mode + NodePools)"
terraform -chdir="$TF_K8S" init -input=false >/dev/null
terraform -chdir="$TF_K8S" apply -input=false ${APPROVE}

log "Stack 2/3 - platform (Cognito, Bedrock Guardrail, Secrets, ECR + images, IAM, AgentCore Runtime)"
terraform -chdir="$TF_PLATFORM" init -input=false >/dev/null
terraform -chdir="$TF_PLATFORM" apply -input=false ${APPROVE}

log "Stack 3/3 - agentgateway (CRDs, control plane, ESO, inference, MCP, gateway config)"
terraform -chdir="$TF_AGW" init -input=false >/dev/null
terraform -chdir="$TF_AGW" apply -input=false ${APPROVE}

ensure_kubeconfig
log "Waiting for the gateway NLB to become reachable..."
ADDR="$(wait_gateway_ready)" && ok "agentgateway address: http://$ADDR" || warn "Gateway not reachable yet; run ./scripts/get-gateway-url.sh later"
log "Done. Next: ./scripts/tests/run-all-tests.sh"
