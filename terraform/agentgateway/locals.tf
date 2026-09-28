locals {
  k8s      = data.terraform_remote_state.kubernetes.outputs
  platform = data.terraform_remote_state.platform.outputs

  cluster_name  = local.k8s.cluster_name
  allowed_cidrs = local.k8s.allowed_cidrs
}
