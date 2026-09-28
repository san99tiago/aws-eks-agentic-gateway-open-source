provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "kubernetes" {
  backend = "s3"
  config = {
    bucket = "terraform-santigrc-430118815432"
    key    = "agentgateway-santi-open/kubernetes/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "terraform-santigrc-430118815432"
    key    = "agentgateway-santi-open/platform/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

# All Kubernetes objects are applied through Helm (OCI charts + local charts), which only
# connects to the cluster at apply time.
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region]
    }
  }
}
