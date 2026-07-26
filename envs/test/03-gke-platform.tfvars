# ── Test 环境 · 03-gke-platform ──
env          = "test"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-test"

master_ipv4_cidr_block = "172.16.0.16/28"

# Test 演练降本:单区 + 小机型(拓扑与 prod 略异,合规仍对齐)
regional             = false
zones                = ["asia-northeast1-a"]
machine_type         = "e2-medium"
min_count            = 1
max_count            = 2
disk_size_gb         = 30
node_service_account = "sa-fintech-test@kqeardr-gcp-shimano-internal.iam.gserviceaccount.com"
