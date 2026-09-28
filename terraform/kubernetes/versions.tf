terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  # Remote state in S3 with native S3 locking (Terraform >= 1.10, no DynamoDB table needed).
  # Bucket: private, versioned, SSE-AES256. One key per stack under the project prefix.
  backend "s3" {
    bucket       = "terraform-santigrc-430118815432"
    key          = "agentgateway-santi-open/kubernetes/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
