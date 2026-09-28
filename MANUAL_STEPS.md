# MANUAL_STEPS.md - Actions that are intentionally NOT automated

Everything in this repository is Infrastructure as Code. The steps below are the **only** manual
actions, and all of them are optional for the core demo (Bedrock LLM-GW, MCP-GW, Inference
Routing and Guardrails work without them). They exist because real third-party API keys must
never touch git, the terminal or Terraform state (see [ADR-010](docs/adr/ADR-010-secrets-management.md)).

> Perform them in the AWS Console (Chrome). Terraform created the secrets with the placeholder
> value `REPLACE_ME_IN_AWS_CONSOLE` and ignores later changes to the value.

## 0. (Required before `terraform apply` of stack 2) Cognito demo user password

The password is never stored in git. Choose one of:

```bash
cp terraform/platform/secrets.auto.tfvars.example terraform/platform/secrets.auto.tfvars   # git-ignored
# edit the value, or:
export TF_VAR_cognito_demo_user_password='<strong-demo-password>'
```

The test scripts read the same value (or `COGNITO_DEMO_PASSWORD`) to obtain Cognito tokens.

## 1. (Optional) OpenAI API key for the `gpt-5.5` placeholder model

1. Open Secrets Manager in `us-east-1`:
   <https://us-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-1>
2. Open the secret **`agentgateway-santi-open/openai-api-key`**.
3. **Retrieve secret value** -> **Edit** -> **Plaintext** -> paste the OpenAI key (starting with
   `sk-`) as a raw string (no JSON) -> **Save**.
4. Within one hour External Secrets refreshes `agentgateway-system/openai-secret`. To force it:

   ```bash
   kubectl annotate externalsecret openai-secret -n agentgateway-system force-sync=$(date +%s) --overwrite
   ```

5. Test: `GW=$(./scripts/get-gateway-url.sh); curl -s $GW/v1/chat/completions -H 'content-type: application/json' -d '{"model":"gpt-5.5","messages":[{"role":"user","content":"hi"}]}'`

## 2. (Optional) Google Gemini API key for the `gemini-2.5-flash` placeholder model

Same procedure with the secret **`agentgateway-santi-open/gemini-api-key`** (Google AI Studio key).
Kubernetes secret: `agentgateway-system/gemini-secret`.

## 3. (Optional) Use the official gated Gemma weights instead of the ungated mirror

1. Accept the Gemma license at <https://huggingface.co/google/gemma-3-4b-it> and create a
   read token.
2. Store the token in the secret **`agentgateway-santi-open/huggingface-token`** (same procedure).
3. Add an `ExternalSecret` in namespace `inference` that writes key `HF_TOKEN` into a Secret named
   `hf-token`, then set in `terraform/agentgateway/terraform.tfvars`:

   ```hcl
   gemma_model = "google/gemma-3-4b-it"
   ```

   and pass `hfTokenSecret = "hf-token"` in the `inference_gemma` release values. Re-apply stack 3.

## 4. Confirm Amazon Bedrock model access (one time per account)

Bedrock model access is account-wide. The models used (`anthropic.claude-*`, `amazon.nova-*`)
were already enabled in this account (verified with a `converse` call before deploying). In a new
account open <https://us-east-1.console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess>
and enable **Anthropic Claude** and **Amazon Nova** models.

## 5. Update your public IP when it changes

Not a console step, but manual by nature:

```bash
curl -s https://checkip.amazonaws.com          # your current IP
# edit terraform/kubernetes/terraform.tfvars -> allowed_cidrs (append "<ip>/32" with a comment naming the location)
# If you run this from the NEW location, the EKS API is not reachable yet and the Helm provider
# will wrongly plan to CREATE the NodePools release. Open the API first with a targeted apply:
terraform -chdir=terraform/kubernetes apply -target='module.eks.aws_eks_cluster.this[0]'
terraform -chdir=terraform/kubernetes apply     # rest of stack 1 (persists the allowed_cidrs output)
terraform -chdir=terraform/agentgateway apply   # NLB loadBalancerSourceRanges (via remote state)
```

## Status of manual steps for this deployment (2026-09-27)

| Step | Status |
| --- | --- |
| 1 OpenAI key | Not set (placeholder). Model returns an upstream auth error until set. |
| 2 Gemini key | Not set (placeholder). Same behavior. |
| 3 Gated Gemma | Not needed (ungated mirror in use). |
| 4 Bedrock access | Already enabled, verified. |
| 5 IP allow-list | `181.137.32.97/32` (home) and `186.121.142.180/32` (ces-clinic) configured on 2026-09-28. |
| 0 Demo password | Set locally in `secrets.auto.tfvars` (not committed). |
