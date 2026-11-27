#!/usr/bin/env bash
# Opens the agentgateway admin UI (read-only) and the Prometheus metrics endpoint through a
# kubectl port-forward. The UI is never exposed on the NLB on purpose (ADR-013): it lives on the
# proxy pod and is reached only from an operator laptop that already has cluster access.
#
# Usage: ./scripts/ui.sh            # UI on http://localhost:15000/ui/  metrics on http://localhost:15020/metrics
#        UI_PORT=16000 ./scripts/ui.sh
source "$(dirname "$0")/_common.sh"

UI_PORT="${UI_PORT:-15000}"
METRICS_PORT="${METRICS_PORT:-15020}"
NS=agentgateway-system
DEPLOY=deploy/agentgateway-proxy

ensure_kubeconfig
kubectl get "$DEPLOY" -n "$NS" >/dev/null || { fail "agentgateway proxy not found in $NS (is stack 3 applied?)"; exit 1; }

log "Port-forwarding $DEPLOY: UI :$UI_PORT  metrics :$METRICS_PORT  (Ctrl+C to stop)"
kubectl port-forward "$DEPLOY" -n "$NS" "$UI_PORT:15000" "$METRICS_PORT:15020" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null; echo; log "port-forward closed"' EXIT INT TERM

for _ in $(seq 1 20); do
  curl -s -o /dev/null --max-time 2 "http://localhost:$UI_PORT/ui/" && break
  sleep 0.5
done
curl -s -o /dev/null --max-time 3 "http://localhost:$UI_PORT/ui/" || { fail "UI did not answer on :$UI_PORT"; exit 1; }

ok "UI:       http://localhost:$UI_PORT/ui/          (listeners, routes, backends, policies, config dump)"
ok "Metrics:  http://localhost:$METRICS_PORT/metrics   (Prometheus; e.g. agentgateway_gen_ai_client_token_usage)"
ok "Config:   http://localhost:$UI_PORT/config_dump"

if [[ "${OPEN_BROWSER:-1}" == "1" ]]; then
  if command -v open >/dev/null 2>&1; then open "http://localhost:$UI_PORT/ui/"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "http://localhost:$UI_PORT/ui/"
  fi
fi

wait $PF
