# ── Test 环境 · 02-core-db ──
# Test 与 prod 同构:REGIONAL 高可用 + 删除保护,确保"测的就是要部署的"。
env          = "test"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-test"

tier                = "db-custom-2-8192"
availability_type   = "REGIONAL"
deletion_protection = true
