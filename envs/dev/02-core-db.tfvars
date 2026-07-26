# ── Dev 环境 · 02-core-db ──
# Dev 放宽:ZONAL 单点 + 关删除保护 + 小规格,便于反复演练省钱。
# 对应 OPA dev 数据文件放行(policies/data/dev.json)。
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

# 保持 db-custom-1-3840:实例已创建,改共享核会强制重建,而 Cloud SQL 删除后
# 实例名保留约一周无法立即复用 → 会失败。此规格已是最小专用核 + ZONAL,足够省。
tier                = "db-custom-1-3840"
availability_type   = "ZONAL"
deletion_protection = false
