#!/usr/bin/env python3
"""
Minimal MCP test client (FastMCP Client, Streamable HTTP) for the agentgateway MCP Gateway.

Usage:
  python mcp_client.py <url> [--token <bearer>] [--call <tool> '<json-args>']
Examples:
  python mcp_client.py http://$GW/mcp
  python mcp_client.py http://$GW/agentcore/mcp --token "$(../cognito-token.sh)" --call agentcore_multiply '{"a": 6, "b": 7}'
Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys

from fastmcp import Client
from fastmcp.client.transports import StreamableHttpTransport


async def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("url")
    p.add_argument("--token", default=None, help="Bearer token (e.g. Cognito access token)")
    p.add_argument("--call", nargs=2, metavar=("TOOL", "JSON_ARGS"), default=None)
    p.add_argument("--expect-fail", action="store_true", help="Exit 0 if the connection is rejected (negative test)")
    a = p.parse_args()

    headers = {"Authorization": f"Bearer {a.token}"} if a.token else {}
    transport = StreamableHttpTransport(url=a.url, headers=headers)
    try:
        async with Client(transport) as c:
            tools = await c.list_tools()
            print(f"connected: {a.url}")
            print("tools:", json.dumps([t.name for t in tools]))
            if a.call:
                name, raw = a.call
                res = await c.call_tool(name, json.loads(raw))
                print(f"call {name} ->", json.dumps(res.data, default=str))
    except Exception as e:  # noqa: BLE001
        msg = f"{type(e).__name__}: {str(e)[:300]}"
        if a.expect_fail:
            print("rejected as expected ->", msg)
            return 0
        print("ERROR ->", msg, file=sys.stderr)
        return 1
    if a.expect_fail:
        print("ERROR -> expected rejection but the connection succeeded", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
