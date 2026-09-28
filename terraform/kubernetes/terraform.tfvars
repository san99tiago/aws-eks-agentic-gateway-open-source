# Non-secret demo values. Adjust allowed_cidrs to YOUR public IP (curl -s https://checkip.amazonaws.com).
aws_region         = "us-east-1"
name_prefix        = "agentgateway-santi-open"
kubernetes_version = "1.36"
allowed_cidrs      = ["181.137.32.97/32"]
