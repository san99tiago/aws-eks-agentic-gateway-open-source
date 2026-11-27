variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "agentgateway-santi-open"
}

# ---------------- Versions (pinned) ----------------
variable "agentgateway_version" {
  description = "agentgateway Helm chart / image version (cr.agentgateway.dev)."
  type        = string
  default     = "v1.5.0"
}

variable "external_secrets_version" {
  description = "External Secrets Operator Helm chart version."
  type        = string
  default     = "2.11.0"
}

variable "llmd_router_version" {
  description = "llm-d Router Gateway chart version (InferencePool + EPP)."
  type        = string
  default     = "v0.9.0"
}

# ---------------- Namespaces ----------------
variable "gateway_namespace" {
  type    = string
  default = "agentgateway-system"
}

variable "inference_namespace" {
  type    = string
  default = "inference"
}

variable "mcp_namespace" {
  type    = string
  default = "mcp"
}

variable "eso_namespace" {
  type    = string
  default = "external-secrets"
}

# ---------------- Feature toggles ----------------
variable "enable_inference_routing" {
  description = "Deploy Ollama + Gemma (vLLM) on GPU nodes with InferencePools (costs 2x g6.xlarge)."
  type        = bool
  default     = true
}

variable "ollama_model" {
  type    = string
  default = "llama3.2:3b"
}

variable "gemma_model" {
  description = "HF repo for Gemma. Default is the ungated mirror of google/gemma-3-4b-it."
  type        = string
  default     = "unsloth/gemma-3-4b-it"
}

variable "bedrock_models" {
  description = "Client-facing name -> Bedrock model id / inference profile. dropParams: OpenAI request fields the upstream model rejects; the gateway nulls them before translating to Converse. openaiReasoningEffort: Converse additionalModelRequestFields.reasoning.effort for OpenAI models."
  type = list(object({
    name                  = string
    modelId               = string
    dropParams            = optional(list(string), [])
    openaiReasoningEffort = optional(string)
  }))
  default = [
    { name = "claude-sonnet-4-5", modelId = "us.anthropic.claude-sonnet-4-5-20250929-v1:0" },
    { name = "claude-haiku-4-5", modelId = "global.anthropic.claude-haiku-4-5-20251001-v1:0" },
    # OpenAI GPT-6 served by Amazon Bedrock (inference profiles only, no OpenAI key): Luna = economical
    # tier, Sol = premium tier. Both answer ValidationException to temperature and topP. Reasoning
    # effort "none": with any other effort GPT-6 returns reasoningContent.redactedContent, which
    # agentgateway v1.5.0 fails to parse (fixed in v1.6.0 non-streaming / v1.7.0 streaming).
    { name = "gpt-6-luna", modelId = "us.openai.gpt-6-luna", dropParams = ["temperature", "top_p"], openaiReasoningEffort = "none" },
    { name = "gpt-6-sol", modelId = "us.openai.gpt-6-sol", dropParams = ["temperature", "top_p"], openaiReasoningEffort = "none" },
  ]
}

variable "gateway_replicas" {
  type    = number
  default = 2
}
