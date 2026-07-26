# ── Dev 环境 · 03-gke-platform ──
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

# 控制平面 /28,各环境不同,避免单项目内 peering 冲突
master_ipv4_cidr_block = "172.16.0.0/28"

# Dev 小规格省钱
machine_type = "e2-standard-2"
min_count    = 1
max_count    = 2
