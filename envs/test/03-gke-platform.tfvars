# ── Test 环境 · 03-gke-platform ──
env          = "test"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-test"

master_ipv4_cidr_block = "172.16.0.16/28"

machine_type = "e2-standard-4"
min_count    = 1
max_count    = 2
