"""
agent1.py - Strands Agent on Amazon Bedrock (Claude Haiku 4.5 by default) THROUGH agentgateway,
with DEMO banking tools (consulta_saldo, estado_canales, movimientos, tasa_cambio, bloquear_tarjeta...).

The agent never touches AWS credentials: it speaks OpenAI chat completions to the gateway NLB and the
gateway (EKS Pod Identity) calls Bedrock with the native Guardrail. Tool calls are translated
OpenAI <-> Bedrock by agentgateway.

Usage:
  .venv/bin/python scripts/agents/agent1.py                                  # interactive chat, all tools
  .venv/bin/python scripts/agents/agent1.py "Cual es el saldo de ahorros-1234?"  # one-shot
  .venv/bin/python scripts/agents/agent1.py --tools consulta-saldo,estado-canales
  .venv/bin/python scripts/agents/agent1.py --model gpt-6-sol "Hay canales caidos?"   # OpenAI GPT-6 Sol on Bedrock

Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))  # allow running from the repo root

from common import build_model, parse_args, run
from strands import Agent
from tools_banco import select_tools

SYSTEM_PROMPT = (
    "Eres un asistente bancario paisa, conciso y tecnico. Respondes en espanol. "
    "Usa las herramientas disponibles para consultar saldos, movimientos, estado de canales, "
    "tasas de cambio o bloquear tarjetas. Los datos son de DEMO. Nunca inventes cifras: si no "
    "tienes la herramienta, dilo."
)


def main() -> None:
    args = parse_args("Strands agent -> agentgateway -> Amazon Bedrock", default_model="claude-haiku-4-5")
    agent = Agent(model=build_model(args), tools=select_tools(args.tools), system_prompt=SYSTEM_PROMPT)
    run(agent, args, tag="agent1")


if __name__ == "__main__":
    main()
