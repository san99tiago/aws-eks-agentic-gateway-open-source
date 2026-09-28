"""
agent1.py - Strands Agent that talks to Amazon Bedrock (Claude Haiku 4.5) THROUGH agentgateway.

The agent never touches AWS credentials or the Bedrock API: it speaks plain OpenAI chat
completions to the gateway NLB, and the gateway (EKS Pod Identity) calls Bedrock with the
native Bedrock Guardrail attached.

Usage:
  export AGENTGATEWAY_URL=$(./scripts/get-gateway-url.sh)     # optional, auto-detected with kubectl
  .venv/bin/python scripts/agents/agent1.py "Explain EKS Auto Mode in two sentences"
  MODEL=nova-lite .venv/bin/python scripts/agents/agent1.py "hola"   # any Bedrock alias of the catalog

Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import os
import subprocess
import sys

import datetime as dt

from strands import Agent, tool
from strands.models.openai import OpenAIModel

MODEL = os.getenv("MODEL", "claude-haiku-4-5")  # client-facing alias defined in AgentgatewayModel


@tool
def hora_colombia() -> str:
    """Devuelve la fecha y hora actual en Colombia (UTC-5)."""
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-5)))
    return now.strftime("%Y-%m-%d %H:%M:%S (Colombia, UTC-5)")


# NOTE: Strands always sends the "tools" list. Bedrock (through the gateway) rejects an EMPTY
# list with HTTP 400 "The provided request is not valid", so this agent always carries one tool.
# The tool call round-trip (OpenAI tool_calls <-> Bedrock toolUse) is translated by agentgateway.


def gateway_url() -> str:
    """AGENTGATEWAY_URL env var, or the Gateway status address via kubectl."""
    url = os.getenv("AGENTGATEWAY_URL")
    if not url:
        addr = subprocess.check_output(
            ["kubectl", "get", "gateway", "agentgateway-proxy", "-n", "agentgateway-system",
             "-o", "jsonpath={.status.addresses[0].value}"], text=True).strip()
        url = f"http://{addr}"
    return url.rstrip("/")


def main() -> None:
    prompt = " ".join(sys.argv[1:]) or "En una frase, quien eres y quien te construyo?"
    base_url = f"{gateway_url()}/v1"

    model = OpenAIModel(
        client_args={
            "base_url": base_url,      # agentgateway LLM-GW (OpenAI-compatible)
            "api_key": "not-needed",   # auth to Bedrock is done by the gateway (Pod Identity)
        },
        model_id=MODEL,
        params={"max_tokens": 300, "temperature": 0.3},
    )

    agent = Agent(
        model=model,
        tools=[hora_colombia],
        system_prompt="Eres un asistente paisa, conciso y tecnico. Respondes en espanol.",
        callback_handler=None,  # no streaming to stdout; we print the final result
    )

    print(f"[agent1] gateway={base_url} model={MODEL}\n")
    result = agent(prompt)
    print(result)
    usage = result.metrics.accumulated_usage
    print(f"\n[agent1] tokens in={usage['inputTokens']} out={usage['outputTokens']} total={usage['totalTokens']}")


if __name__ == "__main__":
    main()
