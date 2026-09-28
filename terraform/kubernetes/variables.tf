variable "aws_region" {
  description = "AWS region for the whole solution."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Naming standard applied to every resource."
  type        = string
  default     = "agentgateway-santi-open"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (latest STANDARD_SUPPORT default at time of writing)."
  type        = string
  default     = "1.36"
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. MUST be your own IP(s), never 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = length([for c in var.allowed_cidrs : c if c == "0.0.0.0/0"]) == 0
    error_message = "0.0.0.0/0 is forbidden for the EKS API endpoint. Use your own /32."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.42.0.0/16"
}

variable "azs_count" {
  description = "Number of Availability Zones to use."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost-optimized for a demo/dev environment)."
  type        = bool
  default     = true
}

variable "general_pool" {
  description = "EKS Auto Mode custom NodePool for general workloads (medium-tier Graviton instances)."
  type = object({
    instance_families = list(string)
    instance_sizes    = list(string)
    architecture      = string
    cpu_limit         = string
    disk_size         = string
  })
  default = {
    instance_families = ["m7g", "m8g"]
    instance_sizes    = ["large", "xlarge"]
    architecture      = "arm64"
    cpu_limit         = "32"
    disk_size         = "80Gi"
  }
}

variable "gpu_pool" {
  description = "EKS Auto Mode custom NodePool for GPU inference workloads (medium-tier NVIDIA L4 instances)."
  type = object({
    instance_families = list(string)
    instance_sizes    = list(string)
    architecture      = string
    gpu_limit         = string
    cpu_limit         = string
    disk_size         = string
  })
  default = {
    instance_families = ["g6"]
    instance_sizes    = ["xlarge"]
    architecture      = "amd64"
    gpu_limit         = "2"
    cpu_limit         = "16"
    disk_size         = "150Gi"
  }
}

variable "enable_cloudwatch_observability" {
  description = "Install the amazon-cloudwatch-observability EKS add-on (Container Insights + logs)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
