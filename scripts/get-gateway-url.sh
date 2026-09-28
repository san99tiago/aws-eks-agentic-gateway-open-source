#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
ensure_kubeconfig
ADDR="$(gateway_address)"
[[ -z "$ADDR" ]] && { fail "Gateway has no address yet. Check: kubectl get gateway -n agentgateway-system"; exit 1; }
echo "http://$ADDR"
