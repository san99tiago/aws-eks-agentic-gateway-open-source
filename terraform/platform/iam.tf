################################################################################
# IAM - least privilege roles
#  1. agentgateway proxy (EKS Pod Identity): Bedrock invoke + ApplyGuardrail + AgentCore invoke
#  2. External Secrets Operator (EKS Pod Identity): read the LLM API key secrets
#  3. AgentCore Runtime execution role: pull image from ECR, write logs/metrics/traces
################################################################################

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

# ---------- 1. agentgateway proxy ----------
resource "aws_iam_role" "gateway" {
  name               = "${var.name_prefix}-gateway-role"
  description        = "EKS Pod Identity role used by the agentgateway proxy pods (SigV4 to Bedrock and AgentCore)."
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "gateway" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*:${local.account_id}:inference-profile/*",
    ]
  }

  statement {
    sid       = "BedrockGuardrails"
    effect    = "Allow"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [aws_bedrock_guardrail.this.guardrail_arn]
  }

  statement {
    sid    = "AgentCoreInvoke"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
    ]
    resources = [
      aws_bedrockagentcore_agent_runtime.mcp.agent_runtime_arn,
      "${aws_bedrockagentcore_agent_runtime.mcp.agent_runtime_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "gateway" {
  name   = "${var.name_prefix}-gateway-policy"
  role   = aws_iam_role.gateway.id
  policy = data.aws_iam_policy_document.gateway.json
}

resource "aws_eks_pod_identity_association" "gateway" {
  cluster_name    = local.cluster_name
  namespace       = var.gateway_namespace
  service_account = var.gateway_service_account
  role_arn        = aws_iam_role.gateway.arn
  tags            = local.tags
}

# ---------- 2. External Secrets Operator ----------
resource "aws_iam_role" "eso" {
  name               = "${var.name_prefix}-external-secrets-role"
  description        = "EKS Pod Identity role for External Secrets Operator to read ${var.name_prefix}/* secrets."
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "eso" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:${var.name_prefix}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eso" {
  name   = "${var.name_prefix}-external-secrets-policy"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = local.cluster_name
  namespace       = var.eso_namespace
  service_account = var.eso_service_account
  role_arn        = aws_iam_role.eso.arn
  tags            = local.tags
}

# ---------- 3. AgentCore Runtime execution role ----------
data "aws_iam_policy_document" "agentcore_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock-agentcore:${var.aws_region}:${local.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "agentcore" {
  name               = "${var.name_prefix}-agentcore-runtime-role"
  description        = "Execution role for the AgentCore Runtime hosting the sample MCP server."
  assume_role_policy = data.aws_iam_policy_document.agentcore_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "agentcore" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "ECRPull"
    effect    = "Allow"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [aws_ecr_repository.this["agentcore-mcp"].arn]
  }
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
      "logs:DescribeLogGroups", "logs:DescribeLogStreams",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${local.account_id}:log-group:/aws/bedrock-agentcore/*"]
  }
  statement {
    sid    = "Telemetry"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetSamplingRules", "xray:GetSamplingTargets",
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "WorkloadIdentity"
    effect    = "Allow"
    actions   = ["bedrock-agentcore:GetWorkloadAccessToken", "bedrock-agentcore:GetWorkloadAccessTokenForJWT", "bedrock-agentcore:GetWorkloadAccessTokenForUserId"]
    resources = ["arn:${data.aws_partition.current.partition}:bedrock-agentcore:${var.aws_region}:${local.account_id}:workload-identity-directory/default*"]
  }
}

resource "aws_iam_role_policy" "agentcore" {
  name   = "${var.name_prefix}-agentcore-runtime-policy"
  role   = aws_iam_role.agentcore.id
  policy = data.aws_iam_policy_document.agentcore.json
}
