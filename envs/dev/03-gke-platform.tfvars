# ── Dev 环境 · 03-gke-platform ──
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

# 控制平面 /28,各环境不同,避免单项目内 peering 冲突
master_ipv4_cidr_block = "172.16.0.0/28"

# Dev 成本最优:单区集群 + 单节点 + 小机型 + 小盘 + 复用 dev 部署 SA 作节点身份
regional             = false
zones                = ["asia-northeast1-a"]
machine_type         = "e2-medium"
min_count            = 1
max_count            = 1
disk_size_gb         = 30
node_service_account = "sa-fintech-dev@kqeardr-gcp-shimano-internal.iam.gserviceaccount.com"
