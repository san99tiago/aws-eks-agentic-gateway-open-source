"""
agent2.py - Strands Agent on a SELF-HOSTED open model THROUGH agentgateway, with the same DEMO
banking tools as agent1.

Default model: llama3.2 (Ollama, InferencePool "ollama") because it supports OpenAI tool calling.
Alternative:   gemma-3-4b-it (vLLM, InferencePool "gemma"); the vLLM deployment has no tool parser,
so use --tools none with it (plain chat).
The gateway routes by model name to the InferencePool, the llm-d endpoint picker chooses the pod, and
the Bedrock Guardrail is still enforced through the ApplyGuardrail prompt guard (HTTP 403 when blocked).

Usage:
  .venv/bin/python scripts/agents/agent2.py                                 # interactive, llama3.2, all tools
  .venv/bin/python scripts/agents/agent2.py "Que canales estan degradados?"
  .venv/bin/python scripts/agents/agent2.py --model gemma-3-4b-it --tools none "Who are you?"

Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import build_model, parse_args, run
from strands import Agent
from tools_banco import select_tools


def main() -> None:
    args = parse_args("Strands agent -> agentgateway -> self-hosted InferencePool", default_model="llama3.2")
    # No system prompt on purpose: on non-Bedrock models the guardrail runs through ApplyGuardrail on the
    # raw text and the PROMPT_ATTACK filter (HIGH) flags instruction-like system prompts as injection (403).
    # Style instructions go in the user turn instead.
    agent = Agent(model=build_model(args), tools=select_tools(args.tools))
    run(agent, args, tag="agent2")


if __name__ == "__main__":
    main()
