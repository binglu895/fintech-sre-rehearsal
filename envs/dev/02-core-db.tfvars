# ── Dev 环境 · 02-core-db ──
# Dev 放宽:ZONAL 单点 + 关删除保护 + 小规格,便于反复演练省钱。
# 对应 OPA dev 数据文件放行(policies/data/dev.json)。
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

tier                = "db-f1-micro" # 最便宜的共享核(ZONAL 才支持),dev 演练够用
availability_type   = "ZONAL"
deletion_protection = false
