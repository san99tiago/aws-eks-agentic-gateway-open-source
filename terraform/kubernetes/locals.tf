data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.name_prefix}-eks"
  azs          = slice(data.aws_availability_zones.available.names, 0, var.azs_count)

  tags = merge({
    Project     = var.name_prefix
    Environment = "open-source-demo"
    ManagedBy   = "terraform"
    Owner       = "santigrc"
    Stack       = "kubernetes"
  }, var.tags)
}
