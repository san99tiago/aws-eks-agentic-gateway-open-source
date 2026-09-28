# syntax=docker/dockerfile:1.7
# MCP server for Amazon Bedrock AgentCore Runtime. MUST be linux/arm64.
# Build: docker buildx build --platform linux/arm64 -t <ecr>/agentcore-mcp:v1 --push .
FROM --platform=linux/arm64 python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN pip install --no-cache-dir "fastmcp>=2.12,<3" "uvicorn>=0.30"

RUN useradd --create-home --uid 10001 mcp
WORKDIR /app
COPY server.py /app/server.py
USER 10001

EXPOSE 8000
CMD ["python", "/app/server.py"]
