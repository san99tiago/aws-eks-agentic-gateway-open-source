# ADR-013: Observability - CloudWatch Container Insights, agentgateway UI and control-plane logs

- Status: Accepted
- Date: 2026-09-27

## Decision

- EKS add-on `amazon-cloudwatch-observability` (Pod Identity role with
  `CloudWatchAgentServerPolicy`) for Container Insights, application logs and GPU (DCGM) metrics.
- `metrics-server` add-on for `kubectl top` and HPA readiness.
- Control-plane logs (api, audit, authenticator, controllerManager, scheduler) and VPC flow logs
  to CloudWatch (14 days).
- agentgateway read-only UI on port 15000 through `kubectl port-forward` (never exposed).
- agentgateway emits OpenTelemetry metrics/traces; exporting to CloudWatch via ADOT is a
  documented follow-up, not deployed (KISS).
