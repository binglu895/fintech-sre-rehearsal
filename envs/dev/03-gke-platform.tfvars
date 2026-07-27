# ── Dev 环境 · 03-gke-platform ──
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

# 控制平面 /28,各环境不同,避免单项目内 peering 冲突
master_ipv4_cidr_block = "172.16.0.0/28"

# Dev 单区集群 + e2-medium。固定 3 节点(min=max)以承载 Bank of Anthos ~10 个 pod:
# 确定性、成本可预测、无自动伸缩扰动。
# (弹性伸缩 min<max 留到 Phase 2 专门测 autoscaler 时再开。)
regional             = false
zones                = ["asia-northeast1-a"]
machine_type         = "e2-medium"
min_count            = 3
max_count            = 3
disk_size_gb         = 30
node_service_account = "sa-fintech-dev@kqeardr-gcp-shimano-internal.iam.gserviceaccount.com"
