# ── Prod 环境 · 03-gke-platform ──
env          = "prod"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-prod"

master_ipv4_cidr_block = "172.16.0.32/28"

# Prod:区域级集群(跨可用区高可用)。演练降本用 e2-standard-2,真实可上调。
regional             = true
zones                = []
machine_type         = "e2-standard-2"
min_count            = 1
max_count            = 3
disk_size_gb         = 50
node_service_account = "sa-fintech-prod@kqeardr-gcp-shimano-internal.iam.gserviceaccount.com"
