"""
Sample MCP server (FastMCP) running INSIDE EKS, fronted by agentgateway (MCP Gateway).

Transport: MCP Streamable HTTP, stateless, path /mcp, port 8000.
Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import datetime as dt
import os
import platform
import socket

import uvicorn
from fastmcp import FastMCP

mcp = FastMCP(
    name="santi-eks-tools",
    instructions="Demo tools served from a FastMCP server running on Amazon EKS behind agentgateway.",
)


@mcp.tool
def eks_hello(name: str = "Santi") -> str:
    """Say hello from the EKS-hosted MCP server. Returns pod hostname to prove where it ran."""
    return f"Hola {name}, parcero! Saludos desde el pod '{socket.gethostname()}' en EKS (agentgateway-santi-open)."


@mcp.tool
def eks_add(a: float, b: float) -> float:
    """Add two numbers (deterministic tool for gateway/agent testing)."""
    return a + b


@mcp.tool
def eks_now(timezone_offset_hours: int = -5) -> str:
    """Current UTC time and the time at the given UTC offset (default -5 = Colombia)."""
    now = dt.datetime.now(dt.timezone.utc)
    local = now + dt.timedelta(hours=timezone_offset_hours)
    return f"UTC: {now.isoformat(timespec='seconds')} | UTC{timezone_offset_hours:+d}: {local.isoformat(timespec='seconds')}"


@mcp.tool
def eks_runtime_info() -> dict:
    """Return runtime metadata (namespace, pod, node, arch) injected by Kubernetes."""
    return {
        "server": "santi-eks-tools",
        "pod": socket.gethostname(),
        "namespace": os.getenv("POD_NAMESPACE", "unknown"),
        "node": os.getenv("NODE_NAME", "unknown"),
        "arch": platform.machine(),
        "python": platform.python_version(),
    }


@mcp.resource("eks://about")
def about() -> str:
    """Static resource describing this MCP server."""
    return "FastMCP sample running on Amazon EKS (Auto Mode, Graviton), exposed through agentgateway MCP Gateway."


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    app = mcp.http_app(path="/mcp", stateless_http=True)
    uvicorn.run(app, host="0.0.0.0", port=port, log_level=os.getenv("LOG_LEVEL", "info"))
