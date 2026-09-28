# ADR-001: Amazon EKS Auto Mode instead of managed node groups

- Status: Accepted
- Date: 2026-09-27
- Deciders: Santiago Garcia Arango

## Context

The brief asks for an "up-to-date, simple, secure, KISS" Kubernetes cluster that must run
CPU workloads (agentgateway, controllers, MCP servers) **and** GPU inference (Ollama, vLLM),
expose a load balancer restricted to one IP, and be easy to create and destroy with Terraform.

A classic EKS design needs: managed node groups per architecture, the NVIDIA device plugin,
VPC CNI / CoreDNS / kube-proxy / EBS CSI add-ons, the AWS Load Balancer Controller, the Pod
Identity agent, Karpenter for right-sizing, and an upgrade process for all of them.

## Decision

Use **EKS Auto Mode** (Kubernetes 1.36, latest STANDARD_SUPPORT version at deploy time):

- AWS manages nodes (built-in Karpenter), networking (VPC CNI, CoreDNS, kube-proxy), storage
  (EBS CSI), load balancing (built-in ALB/NLB controller), GPU drivers/device plugin and the
  Pod Identity agent.
- Only the built-in `system` NodePool is enabled. Application capacity comes from two custom
  NodePools/NodeClasses (`terraform/kubernetes/charts/eks-auto-mode-nodepools`) that pin the
  allowed instance families and sizes (see ADR-004).
- Node OS is AWS-managed Bottlerocket with automatic patching; nodes expire after 14 days
  (`expireAfter: 336h`, Auto Mode caps `expireAfter + terminationGracePeriod` at 21 days).

## Consequences

- Fewer than 10 Terraform resources for a production-grade cluster; no add-on version matrix.
- ~12% Auto Mode management fee on EC2 compute, accepted for the operational simplicity.
- Add-ons must be Auto Mode compatible; `eks-pod-identity-agent` is not installed as an add-on
  because Auto Mode ships it built-in (verified via `describe-addon-versions computeTypes`).
- `Service type=LoadBalancer` must set `loadBalancerClass: eks.amazonaws.com/nlb`; done through
  `AgentgatewayParameters` (ADR-005).

## Alternatives considered

- **Managed node groups + add-ons managed by Terraform**: full control, 3x more moving parts.
- **Karpenter self-managed**: same result as Auto Mode with more operational load.
- **ECS / Fargate**: not Kubernetes; agentgateway's Kubernetes mode (Gateway API) is the target.
