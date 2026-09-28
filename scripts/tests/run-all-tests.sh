#!/usr/bin/env bash
# Runs every test suite. Usage: ./scripts/tests/run-all-tests.sh
D="$(dirname "$0")"
for t in test-llm-gw.sh test-guardrails.sh test-mcp-eks.sh test-mcp-agentcore.sh test-inference-routing.sh; do
  echo; echo "=================== $t ==================="; bash "$D/$t" || echo "!! $t reported failures"
done
