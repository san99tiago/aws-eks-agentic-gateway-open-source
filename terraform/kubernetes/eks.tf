################################################################################
# EKS Auto Mode cluster
#  - Public endpoint restricted to var.allowed_cidrs (your IP only)
#  - Private endpoint enabled for in-VPC access
#  - Envelope encryption (KMS) for Kubernetes secrets (module default)
#  - Control-plane logs to CloudWatch
#  - Built-in "system" NodePool + custom medium-tier NodePools (nodepools.tf)
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.26"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.allowed_cidrs
  endpoint_private_access      = true

  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # The identity running terraform gets cluster-admin via an EKS Access Entry
  enable_cluster_creator_admin_permissions = true

  # EKS Auto Mode: AWS manages nodes (Karpenter), VPC CNI, CoreDNS, kube-proxy,
  # EBS CSI, Load Balancer controller and the Pod Identity agent.
  compute_config = {
    enabled    = true
    node_pools = ["system"] # only the built-in system pool; app pools are custom (medium-tier)
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

################################################################################
# EKS add-ons (created AFTER the custom NodePools exist so their pods can schedule)
################################################################################

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [helm_release.auto_mode_nodepools]
  tags       = local.tags
}

# IAM role for the CloudWatch agent (EKS Pod Identity)
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_agent" {
  count              = var.enable_cloudwatch_observability ? 1 : 0
  name               = "${var.name_prefix}-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_cloudwatch_observability ? 1 : 0
  role       = aws_iam_role.cloudwatch_agent[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  count                       = var.enable_cloudwatch_observability ? 1 : 0
  cluster_name                = module.eks.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  pod_identity_association {
    role_arn        = aws_iam_role.cloudwatch_agent[0].arn
    service_account = "cloudwatch-agent"
  }

  depends_on = [helm_release.auto_mode_nodepools, aws_eks_addon.metrics_server]
  tags       = local.tags
}
