################################################################################
# Amazon ECR - private repositories for the two sample MCP servers
################################################################################

locals {
  images = {
    fastmcp-eks = {
      context     = "${path.module}/../../apps/fastmcp-eks"
      platform    = "linux/arm64" # Graviton general NodePool
      description = "Sample FastMCP server running in EKS behind agentgateway (MCP Gateway)."
    }
    agentcore-mcp = {
      context     = "${path.module}/../../apps/agentcore-mcp"
      platform    = "linux/arm64" # AgentCore Runtime requires arm64
      description = "Sample FastMCP server for Amazon Bedrock AgentCore Runtime (MCP protocol, Cognito JWT)."
    }
  }
}

resource "aws_ecr_repository" "this" {
  for_each = local.images

  name                 = "${var.name_prefix}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # demo environment: allow terraform destroy with images inside

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags # ECR tag values do not accept parentheses; description kept in locals only
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

################################################################################
# Build & push (docker buildx). Re-runs when the app sources change.
################################################################################

resource "terraform_data" "image" {
  for_each = var.build_images ? local.images : {}

  triggers_replace = [
    sha1(join("", [for f in fileset(each.value.context, "**") : filesha1("${each.value.context}/${f}")])),
    var.image_tag,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      REPO="${aws_ecr_repository.this[each.key].repository_url}"
      REGISTRY="$${REPO%%/*}"
      echo ">> Logging in to $REGISTRY"
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin "$REGISTRY"
      echo ">> Building ${each.key} for ${each.value.platform} -> $REPO:${var.image_tag}"
      docker buildx build --platform ${each.value.platform} --provenance=false --sbom=false \
        -t "$REPO:${var.image_tag}" -t "$REPO:latest" --push "${each.value.context}"
      echo ">> Pushed $REPO:${var.image_tag}"
    EOT
  }
}
