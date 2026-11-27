"""
common.py - shared plumbing for the Strands sample agents: gateway URL, CLI args, interactive loop.

Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

from strands import Agent
from strands.models.openai import OpenAIModel
from tools_banco import TOOLS, select_tools

EXIT_WORDS = {"salir", "exit", "quit", "q", "chao"}


class GatewayOpenAIModel(OpenAIModel):
    """OpenAIModel that omits the empty "tools" list Strands sends when the agent has no tools.

    Bedrock (through agentgateway) answers HTTP 400 to tools=[], and vLLM without a tool parser
    also dislikes it. With --tools none this keeps the request clean.
    """

    def format_request(self, *args, **kwargs):  # type: ignore[override]
        request = super().format_request(*args, **kwargs)
        if not request.get("tools"):
            request.pop("tools", None)
            request.pop("tool_choice", None)
        return request


def gateway_url() -> str:
    """AGENTGATEWAY_URL env var, or the Gateway status address via kubectl."""
    url = os.getenv("AGENTGATEWAY_URL", "").strip()
    if not url:
        try:
            addr = subprocess.check_output(
                ["kubectl", "get", "gateway", "agentgateway-proxy", "-n", "agentgateway-system",
                 "-o", "jsonpath={.status.addresses[0].value}"], text=True, timeout=20).strip()
        except (subprocess.SubprocessError, FileNotFoundError) as exc:
            raise SystemExit(f"cannot resolve the gateway address with kubectl ({exc}). "
                             "Set AGENTGATEWAY_URL=http://<nlb-hostname> (./scripts/get-gateway-url.sh) "
                             "and check that your public IP is in allowed_cidrs.") from exc
        if not addr:
            raise SystemExit("Gateway has no address yet: kubectl get gateway -n agentgateway-system")
        url = f"http://{addr}"
    return url.rstrip("/")


def parse_args(description: str, default_model: str, default_tools: str = "all") -> argparse.Namespace:
    p = argparse.ArgumentParser(description=description)
    p.add_argument("prompt", nargs="*", help="one-shot prompt; omit it for interactive mode")
    p.add_argument("--model", default=os.getenv("MODEL", default_model),
                   help="client-facing model alias of the gateway catalog (env MODEL)")
    p.add_argument("--tools", default=os.getenv("TOOLS", default_tools),
                   help=f"'all', 'none' or comma list of: {', '.join(TOOLS)} (env TOOLS)")
    p.add_argument("--max-tokens", type=int, default=600)
    p.add_argument("--temperature", type=float, default=0.2)
    return p.parse_args()


def build_model(args: argparse.Namespace) -> GatewayOpenAIModel:
    return GatewayOpenAIModel(
        client_args={
            "base_url": f"{gateway_url()}/v1",  # agentgateway LLM-GW (OpenAI-compatible)
            "api_key": "not-needed",            # the gateway authenticates upstream (Pod Identity)
        },
        model_id=args.model,
        params={"max_tokens": args.max_tokens, "temperature": args.temperature},
    )


def run(agent: Agent, args: argparse.Namespace, tag: str) -> None:
    """One-shot when a prompt was given on the CLI, otherwise an interactive chat with memory."""
    tools = select_tools(args.tools)
    print(f"[{tag}] gateway={gateway_url()}/v1 model={args.model} tools={[t.tool_name for t in tools] or 'none'}")

    if args.prompt:
        _ask(agent, " ".join(args.prompt), tag)
        return

    print(f"[{tag}] modo interactivo. Escribe tu pregunta, o 'salir' para terminar.\n")
    while True:
        try:
            text = input("tu > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nchao!")
            return
        if not text:
            continue
        if text.lower() in EXIT_WORDS:
            print("chao!")
            return
        _ask(agent, text, tag)


def _ask(agent: Agent, text: str, tag: str) -> None:
    print(f"\n{tag} > ", end="", flush=True)
    try:
        result = agent(text)  # Strands streams text and prints "Tool #n: <name>" through the default handler
    except Exception as exc:  # noqa: BLE001 - e.g. HTTP 403 from the Bedrock Guardrail prompt guard
        print(f"\n[{tag}] request rejected by the gateway -> {type(exc).__name__}: {str(exc)[:300]}", file=sys.stderr)
        return
    u = result.metrics.accumulated_usage
    print(f"\n[{tag}] tokens in={u['inputTokens']} out={u['outputTokens']} total={u['totalTokens']}\n")
