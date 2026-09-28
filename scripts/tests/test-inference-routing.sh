#!/usr/bin/env bash
# Inference routing tests: self-hosted Ollama (llama3.2) and Gemma (vLLM) behind InferencePools + llm-d EPP.
source "$(dirname "$0")/../_common.sh"
set +e  # run every check; the exit code is the number of failed checks
ensure_kubeconfig
GW="${GW:-$(gateway_address)}"; [[ -z "$GW" ]] && { fail "no gateway address"; exit 1; }

log "InferencePools and endpoint pickers"
kubectl get inferencepool -n inference
kubectl get pods -n inference -o wide

log "Waiting for model servers to be Ready (first boot pulls images + weights, up to ~15 min)"
kubectl wait --for=condition=available --timeout=1200s deployment/ollama deployment/gemma-vllm -n inference || warn "model servers not ready yet"

chat() { curl -s --max-time 180 "http://$GW/v1/chat/completions" -H 'content-type: application/json' \
  -d "$(jq -cn --arg m "$1" --arg p "$2" '{model:$m, max_tokens:80, messages:[{role:"user",content:$p}]}')"; }

for m in gemma-3-4b-it llama3.2; do
  log "Route model '$m' -> InferencePool"
  out="$(chat "$m" "In one sentence: what are you and where do you run?")"
  if echo "$out" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    ok "$m: $(echo "$out" | jq -r '.choices[0].message.content' | tr '\n' ' ' | head -c 160) | usage=$(echo "$out" | jq -c '.usage')"
  else fail "$m -> $(echo "$out" | head -c 300)"; fi
done

log "Burst of 6 parallel requests to gemma-3-4b-it (EPP picks endpoints; check EPP logs below)"
for i in $(seq 1 6); do chat gemma-3-4b-it "Reply with the number $i." | jq -r '.choices[0].message.content' | tr '\n' ' ' & done; wait; echo
log "EPP (endpoint picker) recent logs - gemma"
kubectl logs -n inference deploy/gemma-epp --tail=8 2>/dev/null | cut -c1-200 || true

RC=$FAILURES
[[ $RC -eq 0 ]] && ok "suite finished without failures" || fail "suite finished with $RC failed check(s)"
exit $RC
