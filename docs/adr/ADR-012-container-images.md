# ADR-012: arm64 images built by docker buildx from Terraform into ECR

- Status: Accepted
- Date: 2026-09-27

## Context

Two tiny FastMCP servers (EKS and AgentCore) need images in private ECR before the Kubernetes
Deployment and the AgentCore Runtime can start. AgentCore requires linux/arm64.

## Decision

- `aws_ecr_repository` x2 (scan on push, AES256, lifecycle keep 10, `force_delete` for demo).
- `terraform_data.image` runs `docker buildx build --platform linux/arm64 --push` with a trigger
  on the SHA of the app directory; `build_images=false` skips it (CI without Docker).
- Both images are arm64: Graviton general pool and AgentCore share the architecture.

## Consequences

- Requires a running Docker daemon with buildx (colima or Docker Desktop) on the operator machine.
- Re-running apply after editing `apps/*` rebuilds and pushes automatically; AgentCore picks up
  the new tag on the next apply (`image_tag` variable).
