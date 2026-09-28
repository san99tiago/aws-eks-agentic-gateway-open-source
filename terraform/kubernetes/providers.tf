provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

# Helm is used ONLY to apply the EKS Auto Mode NodeClass/NodePool manifests
# (packaged as a tiny local chart). Helm connects at apply-time, so it does not
# need the cluster to exist at plan-time (unlike kubernetes_manifest).
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}
