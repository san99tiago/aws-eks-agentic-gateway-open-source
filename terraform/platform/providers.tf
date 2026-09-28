provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

# Stack 1 outputs (cluster name for EKS Pod Identity associations)
data "terraform_remote_state" "kubernetes" {
  backend = "s3"
  config = {
    bucket = "terraform-santigrc-430118815432"
    key    = "agentgateway-santi-open/kubernetes/terraform.tfstate"
    region = "us-east-1"
  }
}
