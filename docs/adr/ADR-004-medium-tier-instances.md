# ADR-004: Medium-tier instances - Graviton m7g for general workloads, g6.xlarge for inference

- Status: Accepted
- Date: 2026-09-27

## Context

"Every deployment decision must prioritize medium instances (not cheapest, not most expensive)."
Workloads: agentgateway proxy/controller, ESO, EPPs, FastMCP (all multi-arch images), plus two
GPU model servers (Ollama and vLLM).

## Decision

| NodePool | Requirements | Why |
| --- | --- | --- |
| `agentgateway-santi-open-general` | families `m7g`,`m8g`; sizes `large`,`xlarge`; arm64; on-demand; limit 32 vCPU | Graviton general purpose = best price/perf mid tier; every image used is published for arm64 (verified with `docker manifest inspect`). |
| `agentgateway-santi-open-gpu` | family `g6`; size `xlarge`; amd64; NVIDIA; taint `nvidia.com/gpu`; limit 2 GPUs | g6.xlarge = 1x NVIDIA L4 24 GB, 4 vCPU, 16 GiB. Mid-range GPU (above g4dn/g5, below g6e/p-family). One node per model server. |

Disk: 80 GiB (general) / 150 GiB (GPU, vLLM image + weights) gp3 via NodeClass `ephemeralStorage`.

## Consequences

- Estimated steady cost: 2x g6.xlarge (~USD 1.61/h) + 2x m7g.large (~USD 0.16/h) + EKS
  (USD 0.10/h) + NAT + Auto Mode fee = about USD 2.1/h (~USD 50/day). Destroy when idle.
- Cross-compiling is unnecessary: sample MCP images are built for arm64 (same as AgentCore).
- vLLM image is amd64/GPU only, which is why the GPU pool is x86.
