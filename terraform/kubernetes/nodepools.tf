################################################################################
# EKS Auto Mode custom NodeClass + NodePools (medium-tier instances only)
# Applied with Helm (local chart) so plan-time does not need cluster access.
################################################################################

resource "helm_release" "auto_mode_nodepools" {
  name      = "${var.name_prefix}-nodepools"
  chart     = "${path.module}/charts/eks-auto-mode-nodepools"
  namespace = "kube-system"

  values = [yamlencode({
    namePrefix        = var.name_prefix
    clusterName       = module.eks.cluster_name
    nodeRoleName      = module.eks.node_iam_role_name
    securityGroupId   = module.eks.cluster_primary_security_group_id
    availabilityZones = local.azs
    general           = var.general_pool
    gpu               = var.gpu_pool
  })]

  wait    = true
  timeout = 600

  depends_on = [module.eks]
}
