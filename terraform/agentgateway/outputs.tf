output "gateway_namespace" {
  value = var.gateway_namespace
}

output "gateway_name" {
  value = "agentgateway-proxy"
}

output "gateway_address_command" {
  description = "Get the public NLB hostname of the agentgateway proxy (restricted to allowed_cidrs)."
  value       = "kubectl get gateway agentgateway-proxy -n ${var.gateway_namespace} -o jsonpath='{.status.addresses[0].value}'"
}

output "llm_models" {
  value = concat(
    [for m in var.bedrock_models : m.name],
    ["gpt-5.5 (placeholder)", "gemini-2.5-flash (placeholder)", "smart (virtual)", "resilient (virtual)"],
    var.enable_inference_routing ? ["gemma-3-4b-it (InferencePool)", "llama3.2 (InferencePool)"] : [],
  )
}

output "mcp_endpoints" {
  value = {
    eks_fastmcp   = "http://<GATEWAY_ADDRESS>/mcp"
    agentcore_mcp = "http://<GATEWAY_ADDRESS>/agentcore/mcp  (Bearer Cognito access token required)"
  }
}

output "ui_port_forward" {
  value = "kubectl port-forward deploy/agentgateway-proxy -n ${var.gateway_namespace} 15000:15000  # then open http://localhost:15000/ui/"
}
