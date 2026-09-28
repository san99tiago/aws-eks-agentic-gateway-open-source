################################################################################
# 1. CRDs: Gateway API (experimental channel) + Inference Extension + agentgateway
################################################################################

resource "helm_release" "gateway_api_crds" {
  name      = "gateway-api-crds"
  chart     = "${path.module}/charts/gateway-api-crds"
  namespace = "kube-system"
  wait      = true
}

resource "helm_release" "inference_extension_crds" {
  name      = "inference-extension-crds"
  chart     = "${path.module}/charts/inference-extension-crds"
  namespace = "kube-system"
  wait      = true
}

resource "helm_release" "agentgateway_crds" {
  name             = "agentgateway-crds"
  repository       = "oci://cr.agentgateway.dev/charts"
  chart            = "agentgateway-crds"
  version          = var.agentgateway_version
  namespace        = var.gateway_namespace
  create_namespace = true
  wait             = true

  depends_on = [helm_release.gateway_api_crds, helm_release.inference_extension_crds]
}

################################################################################
# 2. agentgateway control plane
################################################################################

resource "helm_release" "agentgateway" {
  name       = "agentgateway"
  repository = "oci://cr.agentgateway.dev/charts"
  chart      = "agentgateway"
  version    = var.agentgateway_version
  namespace  = var.gateway_namespace
  wait       = true
  timeout    = 600

  values = [yamlencode({
    # Model-centric LLM API (AgentgatewayModel) - experimental in 1.5.x
    agentgatewayModels = { enabled = true }
    # Gateway API Inference Extension (InferencePool) support
    inferenceExtension = { enabled = true }
    controller = {
      replicaCount = 1
      logLevel     = "info"
    }
    resources = {
      requests = { cpu = "200m", memory = "256Mi" }
      limits   = { memory = "1Gi" }
    }
    commonLabels = { "app.kubernetes.io/part-of" = var.name_prefix }
  })]

  depends_on = [helm_release.agentgateway_crds]
}

################################################################################
# 3. External Secrets Operator (AWS Secrets Manager -> Kubernetes Secrets via Pod Identity)
################################################################################

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  namespace        = var.eso_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    installCRDs    = true
    serviceAccount = { create = true, name = "external-secrets" } # matches the Pod Identity association
    resources      = { requests = { cpu = "50m", memory = "128Mi" } }
    webhook        = { resources = { requests = { cpu = "25m", memory = "64Mi" } } }
    certController = { resources = { requests = { cpu = "25m", memory = "64Mi" } } }
  })]
}

resource "helm_release" "platform_secrets" {
  name      = "platform-secrets"
  chart     = "${path.module}/charts/platform-secrets"
  namespace = var.gateway_namespace
  wait      = true

  values = [yamlencode({
    awsRegion       = var.aws_region
    namePrefix      = var.name_prefix
    targetNamespace = var.gateway_namespace
    secrets = {
      openai-secret = local.platform.secret_names["openai"]
      gemini-secret = local.platform.secret_names["gemini"]
    }
  })]

  depends_on = [helm_release.external_secrets, helm_release.agentgateway]
}

################################################################################
# 4. Inference routing: self-hosted models (GPU) + llm-d Router (InferencePool + EPP)
################################################################################

resource "helm_release" "inference_ollama" {
  count            = var.enable_inference_routing ? 1 : 0
  name             = "ollama-server" # "ollama" is reserved for the InferencePool (llm-d router release)
  chart            = "${path.module}/charts/inference-ollama"
  namespace        = var.inference_namespace
  create_namespace = true
  wait             = false # GPU node provisioning + model pull take several minutes; checked by test scripts

  values = [yamlencode({ model = var.ollama_model })]

  depends_on = [helm_release.agentgateway]
}

resource "helm_release" "inference_gemma" {
  count            = var.enable_inference_routing ? 1 : 0
  name             = "gemma-server" # "gemma" is reserved for the InferencePool (llm-d router release)
  chart            = "${path.module}/charts/inference-gemma-vllm"
  namespace        = var.inference_namespace
  create_namespace = true
  wait             = false

  values = [yamlencode({ model = var.gemma_model })]

  depends_on = [helm_release.agentgateway]
}

locals {
  inference_pools = var.enable_inference_routing ? {
    ollama = { matchLabels = { app = "ollama" }, port = 11434 }
    gemma  = { matchLabels = { app = "gemma-vllm" }, port = 8000 }
  } : {}
}

resource "helm_release" "llmd_router" {
  for_each = local.inference_pools

  name       = each.key # becomes the InferencePool name
  repository = "oci://ghcr.io/llm-d/charts"
  chart      = "llm-d-router-gateway"
  version    = var.llmd_router_version
  namespace  = var.inference_namespace
  wait       = true
  timeout    = 600

  values = [yamlencode({
    provider  = { name = "none" }
    httpRoute = { create = false } # routing is done by AgentgatewayModel (custom provider -> InferencePool)
    router = {
      modelServers = {
        matchLabels = each.value.matchLabels
        targetPorts = [{ number = each.value.port }]
        protocol    = "http"
        type        = "vllm"
      }
      epp = {
        resources = {
          requests = { cpu = "250m", memory = "256Mi" }
          limits   = { memory = "1Gi" }
        }
      }
    }
  })]

  depends_on = [helm_release.inference_extension_crds, helm_release.agentgateway, helm_release.inference_ollama, helm_release.inference_gemma]
}

################################################################################
# 5. MCP server in EKS (FastMCP)
################################################################################

resource "helm_release" "mcp_fastmcp" {
  name             = "fastmcp"
  chart            = "${path.module}/charts/mcp-fastmcp"
  namespace        = var.mcp_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    image = {
      repository = local.platform.ecr_repository_urls["fastmcp-eks"]
      tag        = local.platform.image_tag
    }
  })]

  depends_on = [helm_release.agentgateway]
}

################################################################################
# 6. agentgateway configuration: Gateway, models, MCP backends, routes, policies
################################################################################

resource "helm_release" "agentgateway_config" {
  name      = "agentgateway-config"
  chart     = "${path.module}/charts/agentgateway-config"
  namespace = var.gateway_namespace
  wait      = true

  values = [yamlencode({
    namePrefix = var.name_prefix
    awsRegion  = var.aws_region
    gateway = {
      name         = "agentgateway-proxy"
      namespace    = var.gateway_namespace
      allowedCidrs = local.allowed_cidrs
      replicas     = var.gateway_replicas
    }
    guardrail = {
      identifier = local.platform.guardrail_id
      version    = tostring(local.platform.guardrail_version)
    }
    bedrockModels = var.bedrock_models
    selfHosted = {
      namespace = var.inference_namespace
      models = var.enable_inference_routing ? [
        { name = "gemma-3-4b-it", inferencePool = "gemma", upstreamModel = "gemma-3-4b-it" },
        { name = "llama3.2", inferencePool = "ollama", upstreamModel = var.ollama_model },
      ] : []
    }
    mcp = {
      eks = {
        enabled = true
        host    = "fastmcp.${var.mcp_namespace}.svc.cluster.local"
        port    = 8000
        mcpPath = "/mcp"
        path    = "/mcp"
      }
      agentcore = {
        enabled    = true
        path       = "/agentcore/mcp"
        runtimeArn = local.platform.agentcore_runtime_arn
        cognito = {
          issuer   = local.platform.cognito_issuer
          jwksUrl  = local.platform.cognito_jwks_url
          clientId = local.platform.cognito_app_client_id
        }
      }
    }
  })]

  depends_on = [
    helm_release.agentgateway,
    helm_release.platform_secrets,
    helm_release.mcp_fastmcp,
    helm_release.llmd_router,
  ]
}
