# Step-by-step guide: deploy, validate and destroy

This is the operator runbook for `agentgateway-santi-open`. It complements
[README.md](../README.md) (architecture), [TESTING_INSTRUCTIONS.md](../TESTING_INSTRUCTIONS.md)
(what each test proves) and [VALIDATION_SCRIPT_MANUAL.md](VALIDATION_SCRIPT_MANUAL.md)
(the didactic validator).

| Phase | Wall time | Command |
| --- | --- | --- |
| 0 Prerequisites | 10 min (once) | tool installs below |
| 1 Configure | 2 min | edit `terraform.tfvars` files |
| 2 Deploy | ~35 min | `./scripts/deploy-all.sh -auto-approve` |
| 3 Validate | 5 min | `./scripts/validate_solution_scripts.sh all` |
| 4 Destroy | ~20 min | `./scripts/destroy-all.sh -auto-approve` |

---

## Phase 0 - Prerequisites

### 0.1 Tools

| Tool | Version used | Install (macOS) | Verify |
| --- | --- | --- | --- |
| Terraform | >= 1.10 (tested 1.16.4) | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` | `terraform version` |
| AWS CLI v2 | 2.36 | `brew install awscli` | `aws sts get-caller-identity` |
| kubectl | 1.37 | `brew install kubectl` | `kubectl version --client` |
| Helm | 3.x | `brew install helm` | `helm version` |
| Docker + buildx | colima 29 or Docker Desktop | `brew install colima docker docker-buildx && colima start --cpu 4 --memory 8` | `docker buildx version` |
| Python + Poetry | 3.11+ | `brew install poetry && poetry install --no-root` | `.venv/bin/python -c "import fastmcp"` |
| jq, curl | any | `brew install jq` | `jq --version` |

> The Homebrew core `terraform` formula is frozen at 1.5.7. If it is installed, run
> `brew uninstall terraform` before installing from `hashicorp/tap` (needed for S3 native locking).

### 0.2 AWS account

- Credentials with administrator access to the target account (this repo was deployed to
  `430118815432`, `us-east-1`).
- Amazon Bedrock model access enabled for **Anthropic Claude** and **Amazon Nova**
  (console: Bedrock -> Model access). Quick check:

  ```bash
  aws bedrock-runtime converse --region us-east-1 --model-id us.amazon.nova-lite-v1:0 \
    --messages '[{"role":"user","content":[{"text":"Say OK"}]}]' --query 'output.message.content[0].text'
  ```

- EC2 quota for G instances (`L-DB2E81BA`) >= 8 vCPU (two g6.xlarge).
- An S3 bucket for Terraform state (private, versioned). This repo uses
  `terraform-santigrc-430118815432`.

### 0.3 Your public IP

```bash
curl -s https://checkip.amazonaws.com
```

Everything (EKS API and the gateway NLB) is opened **only** to this `/32`.

---

## Phase 1 - Configure

### 1.1 Allow-list your IP

```bash
MYIP=$(curl -s https://checkip.amazonaws.com)
sed -i '' "s#^allowed_cidrs.*#allowed_cidrs      = [\"$MYIP/32\"]#" terraform/kubernetes/terraform.tfvars
grep allowed_cidrs terraform/kubernetes/terraform.tfvars
```

### 1.2 State backend (only if you use another bucket)

Edit `bucket` in the three `terraform/*/versions.tf` and in the `terraform_remote_state` blocks of
`terraform/platform/providers.tf` and `terraform/agentgateway/providers.tf`. Keys follow
`agentgateway-santi-open/<stack>/terraform.tfstate`.

### 1.3 Optional knobs

| File | Variable | Default | Notes |
| --- | --- | --- | --- |
| `terraform/kubernetes/terraform.tfvars` | `kubernetes_version` | `1.36` | latest STANDARD_SUPPORT at deploy time |
| `terraform/platform/terraform.tfvars` | `cognito_demo_user_email` | `santigrc@amazon.com` | password is NOT in git: `cp terraform/platform/secrets.auto.tfvars.example terraform/platform/secrets.auto.tfvars` and set it (or `export TF_VAR_cognito_demo_user_password=...`) |
| `terraform/platform/terraform.tfvars` | `image_tag` | `v1` | bump to rebuild/push MCP images |
| `terraform/agentgateway/terraform.tfvars` | `enable_inference_routing` | `true` | `false` = no GPU nodes (saves ~USD 1.6/h) |
| `terraform/agentgateway/terraform.tfvars` | `ollama_model` / `gemma_model` | `llama3.2:3b` / `unsloth/gemma-3-4b-it` | |
| `terraform/agentgateway/variables.tf` | `bedrock_models` | 4 inference profiles | client name -> Bedrock model id |

---

## Phase 2 - Deploy

Fast path (runs the three stacks in order and waits for the NLB):

```bash
./scripts/deploy-all.sh -auto-approve
```

Manual path, stack by stack, with what to expect.

### 2.1 Stack 1 - kubernetes (~15 min)

```bash
terraform -chdir=terraform/kubernetes init
terraform -chdir=terraform/kubernetes apply
```

Creates: VPC `agentgateway-santi-open-vpc` (3 AZs, private + public subnets, 1 NAT, flow logs),
EKS Auto Mode cluster `agentgateway-santi-open-eks` (public endpoint = your IP, private endpoint,
KMS secrets encryption, control-plane logs), NodeClasses/NodePools `general` (m7g) and `gpu`
(g6.xlarge), add-ons `metrics-server` and `amazon-cloudwatch-observability`.

Expected end of output:

```text
Apply complete! Resources: 6x added ...
kubeconfig_command = "aws eks update-kubeconfig --region us-east-1 --name agentgateway-santi-open-eks"
```

Verify:

```bash
aws eks update-kubeconfig --region us-east-1 --name agentgateway-santi-open-eks
kubectl get nodepools,nodeclasses          # system + agentgateway-santi-open-general/gpu, READY=True
kubectl get nodes                           # 1 system node (arm64) at this point
```

### 2.2 Stack 2 - platform (~5 min, needs Docker running)

```bash
terraform -chdir=terraform/platform init
terraform -chdir=terraform/platform apply
```

Creates: Cognito user pool + app client + demo user, Bedrock Guardrail + version 1, three
Secrets Manager placeholders, two ECR repositories, **builds and pushes** the two arm64 MCP images
(`docker buildx`), IAM roles + EKS Pod Identity associations (gateway proxy, External Secrets),
AgentCore Runtime execution role and the AgentCore Runtime `agentgateway_santi_open_mcp` (MCP,
Cognito JWT).

Expected end of output (abridged):

```text
agentcore_runtime_arn = "arn:aws:bedrock-agentcore:us-east-1:<acct>:runtime/agentgateway_santi_open_mcp-XXXX"
cognito_app_client_id = "..."
guardrail_id          = "..."
guardrail_version     = "1"
```

Verify:

```bash
aws bedrock-agentcore-control get-agent-runtime --region us-east-1 \
  --agent-runtime-id "$(terraform -chdir=terraform/platform output -raw agentcore_runtime_id)" --query status   # READY
aws eks list-pod-identity-associations --cluster-name agentgateway-santi-open-eks --region us-east-1 \
  --query 'associations[].[namespace,serviceAccount]' --output text
```

### 2.3 Stack 3 - agentgateway (~5 min + ~10 min for GPU model servers in the background)

```bash
terraform -chdir=terraform/agentgateway init
terraform -chdir=terraform/agentgateway apply
```

Creates (Helm): Gateway API CRDs, Inference Extension CRDs, agentgateway CRDs + control plane
(`agentgatewayModels` and `inferenceExtension` enabled), External Secrets Operator + ClusterSecretStore
+ ExternalSecrets, Ollama and vLLM deployments (`ollama-server`, `gemma-server`), two llm-d Router
releases (`ollama`, `gemma` = InferencePool + EPP), FastMCP server, and the `agentgateway-config` chart
(AgentgatewayParameters, Gateway, 10 AgentgatewayModels, 2 AgentgatewayBackends, 2 HTTPRoutes,
1 AgentgatewayPolicy).

Verify:

```bash
kubectl get gateway -n agentgateway-system              # PROGRAMMED=True and an NLB address
kubectl get agentgatewaymodels -A                       # 10 models
kubectl get pods -n inference                           # gemma-vllm may take ~10 min to become 1/1
./scripts/get-gateway-url.sh                            # http://agentgateway-santi-open-nlb-....elb.us-east-1.amazonaws.com
```

The NLB hostname resolves 2-3 minutes after the Gateway is programmed.

---

## Phase 3 - Validate

```bash
./scripts/validate_solution_scripts.sh            # interactive menu
./scripts/validate_solution_scripts.sh all        # full report
./scripts/validate_solution_scripts.sh --help     # manual of options
```

See [VALIDATION_SCRIPT_MANUAL.md](VALIDATION_SCRIPT_MANUAL.md) for every option and
[TESTING_INSTRUCTIONS.md](../TESTING_INSTRUCTIONS.md) for the expected results.

---

## Phase 4 - Destroy

### 4.1 Fast path

```bash
./scripts/destroy-all.sh -auto-approve
```

The script destroys stack 3, waits until no `LoadBalancer` Service remains (so the NLB and its ENIs
are gone), then destroys stacks 2 and 1.

### 4.2 Manual path, with what happens at each step

1. **Stack 3** (`terraform -chdir=terraform/agentgateway destroy`): removes Gateway (the Auto Mode
   controller deletes the NLB), models, backends, MCP server, InferencePools/EPPs, Ollama/vLLM
   (Karpenter drains and terminates the two GPU nodes within ~10 min), External Secrets, CRDs.
   Wait for the NLB to disappear before continuing:

   ```bash
   aws elbv2 describe-load-balancers --region us-east-1 \
     --query 'LoadBalancers[?contains(DNSName,`agentgateway-santi-open-nlb`)].State.Code' --output text   # empty
   ```

2. **Stack 2** (`terraform -chdir=terraform/platform destroy`): AgentCore Runtime, IAM roles and Pod
   Identity associations, ECR repos (`force_delete=true` removes images), Secrets Manager secrets
   (`recovery_window_in_days=0` -> immediate), Guardrail + version, Cognito pool.
3. **Stack 1** (`terraform -chdir=terraform/kubernetes destroy`): add-ons, NodePools, EKS cluster
   (~10 min), VPC (NAT, subnets, flow logs). Auto Mode terminates any remaining node before the
   cluster is deleted.

### 4.3 Post-destroy orphan check (should all be empty)

```bash
R=us-east-1; P=agentgateway-santi-open
aws eks list-clusters --region $R --query "clusters[?contains(@,'$P')]"
aws elbv2 describe-load-balancers --region $R --query "LoadBalancers[?contains(DNSName,'$P')].DNSName"
aws ec2 describe-vpcs --region $R --filters Name=tag:Name,Values=$P-vpc --query 'Vpcs[].VpcId'
aws ec2 describe-security-groups --region $R --filters Name=tag:elbv2.k8s.aws/cluster,Values=$P-eks --query 'SecurityGroups[].GroupId'
aws bedrock list-guardrails --region $R --query "guardrails[?name=='$P-guardrail'].id"
aws cognito-idp list-user-pools --region $R --max-results 50 --query "UserPools[?Name=='$P-users'].Id"
aws ecr describe-repositories --region $R --query "repositories[?starts_with(repositoryName,'$P/')].repositoryName"
aws bedrock-agentcore-control list-agent-runtimes --region $R --query "agentRuntimes[?starts_with(agentRuntimeName,'agentgateway_santi_open')].agentRuntimeName"
aws iam list-roles --query "Roles[?starts_with(RoleName,'$P')].RoleName"
aws secretsmanager list-secrets --region $R --filters Key=name,Values=$P/ --query 'SecretList[].Name'
aws logs describe-log-groups --region $R --log-group-name-prefix /aws/eks/$P --query 'logGroups[].logGroupName'
```

Known leftovers that are safe to delete by hand if they appear: CloudWatch log groups created by
the add-ons (`/aws/containerinsights/...`, `/aws/bedrock-agentcore/...`) and the Terraform state
objects in S3 (kept on purpose; delete the `agentgateway-santi-open/` prefix when you are done).

### 4.4 Partial teardown to save money

```bash
# Keep everything but drop the two GPU nodes (Ollama + Gemma):
sed -i '' 's/enable_inference_routing = true/enable_inference_routing = false/' terraform/agentgateway/terraform.tfvars
terraform -chdir=terraform/agentgateway apply
```

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `NodePool ... expireAfter and terminationGracePeriod may not exceed 21 days` | Auto Mode limit | chart uses `expireAfter: 336h`, `terminationGracePeriod: 24h` (already fixed) |
| `InvalidTagParameterException` creating ECR | tag values with parentheses | ECR repos use plain tags (already fixed) |
| `helm_release ... cannot re-use a name that is still in use` | a previous release failed and stayed in Helm history | `helm uninstall <name> -n <ns>` then re-apply |
| FastMCP pod `CrashLoopBackOff`, `port ... tcp://...` | Kubernetes service links inject `FASTMCP_PORT` | `enableServiceLinks: false` in the Deployment (already fixed) |
| `gemma-3-4b-it` returns 503 | vLLM still pulling image/weights | `kubectl get pods -n inference`; wait for 1/1 (up to 15 min) |
| `curl: (6) Could not resolve host` for the NLB | DNS not propagated yet | wait 2-3 min or `./scripts/get-gateway-url.sh` |
| Timeout from your laptop to the NLB / EKS API | your public IP changed | append your `/32` to `allowed_cidrs`; from the new IP first run `terraform -chdir=terraform/kubernetes apply -target='module.eks.aws_eks_cluster.this[0]'` (otherwise the Helm provider cannot reach the API and plans to re-create the NodePools release), then apply stacks 1 and 3 |
| `gpt-5.5` / `gemini-2.5-flash` return `invalid_api_key` | placeholder key | set the real key in Secrets Manager (MANUAL_STEPS.md) |
| `/agentcore/mcp` returns 401 with a token | ID token instead of ACCESS token, or expired (60 min) | `./scripts/cognito-token.sh` and use `AuthenticationResult.AccessToken` |
| `terraform init` complains about `use_lockfile` | Terraform < 1.10 | install from `hashicorp/tap` |
