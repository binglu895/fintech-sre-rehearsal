# ── Prod 环境 · 03-gke-platform ──
env          = "prod"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-prod"

master_ipv4_cidr_block = "172.16.0.32/28"

# Prod 大规格 + 多节点
machine_type = "e2-standard-4"
min_count    = 2
max_count    = 5
