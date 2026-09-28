{{/* Common labels */}}
{{- define "agw.labels" -}}
app.kubernetes.io/part-of: {{ .Values.namePrefix }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* Bedrock Guardrails prompt guard (ApplyGuardrail API) used on non-Bedrock models */}}
{{- define "agw.bedrockPromptGuard" -}}
promptGuard:
  request:
    - bedrockGuardrails:
        identifier: {{ .Values.guardrail.identifier | quote }}
        version: {{ .Values.guardrail.version | quote }}
        region: {{ .Values.awsRegion }}
        action: Reject
        policies:
          auth:
            aws: {}   # implicit credentials -> EKS Pod Identity role of the proxy
      response:
        statusCode: 403
        message: "[agentgateway-santi-open] Request blocked by Amazon Bedrock Guardrails (prompt guard)."
  response:
    - bedrockGuardrails:
        identifier: {{ .Values.guardrail.identifier | quote }}
        version: {{ .Values.guardrail.version | quote }}
        region: {{ .Values.awsRegion }}
        action: Reject
        policies:
          auth:
            aws: {}
      response:
        statusCode: 403
        message: "[agentgateway-santi-open] Model response blocked by Amazon Bedrock Guardrails (prompt guard)."
{{- end }}
