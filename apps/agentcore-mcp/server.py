"""
Sample MCP server (FastMCP) for Amazon Bedrock AgentCore Runtime (protocol: MCP).

AgentCore Runtime contract for MCP servers:
  - listen on 0.0.0.0:8000
  - path /mcp
  - MCP Streamable HTTP, stateless (AgentCore adds Mcp-Session-Id on its side)
  - linux/arm64 container image in ECR
Inbound auth: Cognito JWT (customJWTAuthorizer) configured in Terraform.
Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import datetime as dt
import os
import platform

import uvicorn
from fastmcp import FastMCP

mcp = FastMCP(
    name="santi-agentcore-tools",
    instructions="Demo tools served from Amazon Bedrock AgentCore Runtime (MCP protocol) behind agentgateway.",
)


@mcp.tool
def agentcore_hello(name: str = "Santi") -> str:
    """Say hello from the AgentCore Runtime hosted MCP server."""
    return f"Hola {name}! Saludos desde Amazon Bedrock AgentCore Runtime (MCP) - agentgateway-santi-open."


@mcp.tool
def agentcore_multiply(a: float, b: float) -> float:
    """Multiply two numbers (deterministic tool for gateway/agent testing)."""
    return a * b


@mcp.tool
def agentcore_weather_demo(city: str = "Medellin") -> dict:
    """Return a DEMO (static) weather record for a city. Not a real forecast."""
    demo = {
        "medellin": {"temp_c": 22, "condition": "Partly cloudy", "humidity": 68},
        "bogota": {"temp_c": 14, "condition": "Rainy", "humidity": 80},
        "cali": {"temp_c": 28, "condition": "Sunny", "humidity": 60},
    }
    return {"city": city, **demo.get(city.lower(), {"temp_c": 25, "condition": "Unknown (demo)", "humidity": 50})}


@mcp.tool
def agentcore_runtime_info() -> dict:
    """Return runtime metadata of the AgentCore container."""
    return {
        "server": "santi-agentcore-tools",
        "arch": platform.machine(),
        "python": platform.python_version(),
        "utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "agentcore_runtime_env": {k: v for k, v in os.environ.items() if k.startswith("AWS_REGION") or k.startswith("BEDROCK_AGENTCORE")},
    }


if __name__ == "__main__":
    app = mcp.http_app(path="/mcp", stateless_http=True)
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level=os.getenv("LOG_LEVEL", "info"))
