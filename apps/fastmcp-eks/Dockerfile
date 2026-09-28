# syntax=docker/dockerfile:1.7
# Sample FastMCP server for EKS (arm64 Graviton nodes). Build: docker buildx build --platform linux/arm64 .
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

RUN pip install --no-cache-dir "fastmcp>=2.12,<3" "uvicorn>=0.30"

# Non-root runtime user
RUN useradd --create-home --uid 10001 mcp
WORKDIR /app
COPY server.py /app/server.py
USER 10001

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import socket;s=socket.create_connection(('127.0.0.1',8000),2);s.close()" || exit 1
CMD ["python", "/app/server.py"]
