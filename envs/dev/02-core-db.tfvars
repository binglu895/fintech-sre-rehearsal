# ── Dev 环境 · 02-core-db ──
# Dev 放宽:ZONAL 单点 + 关删除保护 + 小规格,便于反复演练省钱。
# 对应 OPA dev 数据文件放行(policies/data/dev.json)。
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

tier                = "db-custom-1-3840"
availability_type   = "ZONAL"
deletion_protection = false
