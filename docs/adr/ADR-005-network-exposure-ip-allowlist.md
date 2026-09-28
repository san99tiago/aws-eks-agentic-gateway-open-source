# ADR-005: Exposure - internet-facing NLB and EKS API endpoint restricted to one /32

- Status: Accepted
- Date: 2026-09-27

## Context

Organizational rule: never open APIs to `0.0.0.0/0`. The brief: "EKS ONLY open to my IP address".
The gateway must still be reachable from the operator laptop for testing with curl, OpenAI SDK
and MCP Inspector.

## Decision

- EKS API: `endpoint_public_access_cidrs = ["<my-ip>/32"]` (Terraform validation rejects
  `0.0.0.0/0`) plus private endpoint enabled for in-VPC access.
- Data plane: the agentgateway proxy `Service` is customized through `AgentgatewayParameters`
  (`spec.service`): `loadBalancerClass: eks.amazonaws.com/nlb`, `internet-facing`, IP targets,
  and `loadBalancerSourceRanges = allowed_cidrs`. Auto Mode's controller renders those ranges
  into the NLB security group, so only the allow-listed IP reaches port 80.
- Nodes live in private subnets; egress through one NAT gateway. VPC flow logs to CloudWatch.
- Plain HTTP on the demo listener (no domain owned for this repo). TLS/HTTPS options are
  documented in the README (ACM certificate on the NLB or an HTTPS listener with a Secret).

## Consequences

- Changing location = update `allowed_cidrs` in `terraform/kubernetes/terraform.tfvars` and
  re-apply stacks 1 and 3 (the value is propagated by remote state).
- No public Security Group rules exist anywhere.
