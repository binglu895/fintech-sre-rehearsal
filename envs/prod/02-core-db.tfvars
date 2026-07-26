# ── Prod 环境 · 02-core-db ──
# Prod 满足全部 OPA 红线:REGIONAL + 删除保护 + 无公网 IP。
env          = "prod"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-prod"

tier                = "db-custom-2-8192"
availability_type   = "REGIONAL"
deletion_protection = true
