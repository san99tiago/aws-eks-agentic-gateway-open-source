"""
agent2.py - Strands Agent that talks to a SELF-HOSTED open model THROUGH agentgateway.

Default model: gemma-3-4b-it (vLLM on a g6.xlarge GPU node, behind the "gemma" InferencePool).
Alternative:   llama3.2 (Ollama, "ollama" InferencePool).
The gateway routes by model name to the InferencePool, the llm-d endpoint picker chooses the pod,
and the Bedrock Guardrail is still enforced via the ApplyGuardrail prompt guard (HTTP 403 when blocked).

Usage:
  .venv/bin/python scripts/agents/agent2.py "Who are you and where do you run?"
  MODEL=llama3.2 .venv/bin/python scripts/agents/agent2.py "hola"

Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import os
import subprocess
import sys

from strands import Agent
from strands.models.openai import OpenAIModel

MODEL = os.getenv("MODEL", "gemma-3-4b-it")  # or "llama3.2"


class GatewayOpenAIModel(OpenAIModel):
    """OpenAIModel that omits the empty "tools" list Strands sends when the agent has no tools.

    Some upstreams behind the gateway (Bedrock, vLLM without a tool parser) reject tools=[].
    """

    def format_request(self, *args, **kwargs):  # type: ignore[override]
        request = super().format_request(*args, **kwargs)
        if not request.get("tools"):
            request.pop("tools", None)
            request.pop("tool_choice", None)
        return request


def gateway_url() -> str:
    url = os.getenv("AGENTGATEWAY_URL")
    if not url:
        addr = subprocess.check_output(
            ["kubectl", "get", "gateway", "agentgateway-proxy", "-n", "agentgateway-system",
             "-o", "jsonpath={.status.addresses[0].value}"], text=True).strip()
        url = f"http://{addr}"
    return url.rstrip("/")


def main() -> None:
    prompt = " ".join(sys.argv[1:]) or "In one sentence: what are you and where do you run?"
    base_url = f"{gateway_url()}/v1"

    model = GatewayOpenAIModel(
        client_args={"base_url": base_url, "api_key": "not-needed"},
        model_id=MODEL,
        params={"max_tokens": 200, "temperature": 0.2},
    )

    # No system prompt on purpose: the Bedrock Guardrail PROMPT_ATTACK filter (ApplyGuardrail prompt
    # guard, strength HIGH) flags instruction-like text such as "You are a concise assistant." as a
    # prompt injection and the gateway answers HTTP 403. Put style instructions in the user turn instead.
    agent = Agent(model=model, callback_handler=None)

    print(f"[agent2] gateway={base_url} model={MODEL}\n")
    try:
        result = agent(prompt)
    except Exception as exc:  # noqa: BLE001 - e.g. 403 from the Bedrock Guardrail prompt guard
        print(f"[agent2] request rejected by the gateway -> {type(exc).__name__}: {str(exc)[:300]}")
        sys.exit(1)
    print(result)
    usage = result.metrics.accumulated_usage
    print(f"\n[agent2] tokens in={usage['inputTokens']} out={usage['outputTokens']} total={usage['totalTokens']}")


if __name__ == "__main__":
    main()
