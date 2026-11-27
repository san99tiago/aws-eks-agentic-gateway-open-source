#!/usr/bin/env bash
# LLM Gateway tests: /v1/models discovery + chat completions on Bedrock models and virtual models.
source "$(dirname "$0")/../_common.sh"
set +e  # run every check; the exit code is the number of failed checks
ensure_kubeconfig
GW="${GW:-$(gateway_address)}"; [[ -z "$GW" ]] && { fail "no gateway address"; exit 1; }
log "LLM-GW at http://$GW"

chat() { # chat <model> <prompt> [extra curl args...]
  local model="$1" prompt="$2"; shift 2
  curl -s --max-time 120 "http://$GW/v1/chat/completions" -H 'content-type: application/json' "$@" \
    -d "$(jq -cn --arg m "$model" --arg p "$prompt" '{model:$m, max_tokens:120, messages:[{role:"user",content:$p}]}')"
}

log "1) Model discovery (/v1/models)"
curl -s "http://$GW/v1/models" | jq -r '.data[].id' | sed 's/^/   - /'

for m in claude-sonnet-4-5 claude-haiku-4-5 gpt-6-luna gpt-6-sol; do
  log "2) Bedrock routing -> $m"
  out="$(chat "$m" "In one short sentence, which model are you and who built you?")"
  if echo "$out" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    ok "$m: $(echo "$out" | jq -r '.choices[0].message.content' | head -c 160) | usage=$(echo "$out" | jq -c '.usage')"
  else fail "$m -> $(echo "$out" | head -c 300)"; fi
done

# OpenAI GPT-6 on Bedrock rejects temperature/top_p (ValidationException); the gateway nulls them (dropParams)
for m in gpt-6-luna smart; do
  log "2b) $m with temperature=0.2 and top_p=0.9 (dropped by the gateway before the Converse call)"
  out="$(curl -s --max-time 120 "http://$GW/v1/chat/completions" -H 'content-type: application/json' \
    -d "$(jq -cn --arg m "$m" '{model:$m, temperature:0.2, top_p:0.9, max_tokens:60, messages:[{role:"user",content:"Reply with the word OK."}]}')")"
  if echo "$out" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    ok "$m accepted the request: model=$(echo "$out" | jq -r '.model') content=$(echo "$out" | jq -r '.choices[0].message.content' | head -c 60)"
  else fail "$m with temperature/top_p -> $(echo "$out" | head -c 300)"; fi
done

log "3) Virtual model 'smart' (conditional): default tier -> gpt-6-luna, header x-model-tier: premium -> claude-sonnet-4-5"
chat smart "Say only your model family name." | jq -r '"   default  -> model=\(.model)"'
chat smart "Say only your model family name." -H 'x-model-tier: premium' | jq -r '"   premium  -> model=\(.model)"'

log "4) Virtual model 'resilient' (failover claude-sonnet-4-5 -> gpt-6-sol)"
chat resilient "Reply with the word OK." | jq -r '"   resilient -> model=\(.model) content=\(.choices[0].message.content)"'

log "5) Streaming (SSE) through the gateway"
curl -s -N --max-time 60 "http://$GW/v1/chat/completions" -H 'content-type: application/json' \
  -d '{"model":"claude-haiku-4-5","stream":true,"max_tokens":40,"messages":[{"role":"user","content":"Count from 1 to 5."}]}' | head -c 400 || true; echo

log "6) Placeholders (OpenAI / Gemini): expected to FAIL upstream until real keys are set (MANUAL_STEPS.md)"
for m in gpt-5.5 gemini-2.5-flash; do
  printf "   %-18s -> " "$m"; chat "$m" "hi" | head -c 200; echo
done

RC=$FAILURES
[[ $RC -eq 0 ]] && ok "suite finished without failures" || fail "suite finished with $RC failed check(s)"
exit $RC
