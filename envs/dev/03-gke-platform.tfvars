# ── Dev 环境 · 03-gke-platform ──
env          = "dev"
project_id   = "kqeardr-gcp-shimano-internal"
region       = "asia-northeast1"
state_bucket = "fintech-iac-states-dev"

# 控制平面 /28,各环境不同,避免单项目内 peering 冲突
master_ipv4_cidr_block = "172.16.0.0/28"

# Dev 单区集群,固定 3 节点(min=max,确定性/无伸缩扰动)。
# 机型 e2-standard-2(2 个独占 vCPU/8GB):e2-medium 是共享核,可分配 CPU 仅 ~940m,
# 装不下 Bank of Anthos Cloud SQL 版(每后端多了 proxy sidecar)。
# 注意:改机型会重建节点池(pod 重新调度,Cloud SQL 数据不受影响)。
regional             = false
zones                = ["asia-northeast1-a"]
machine_type         = "e2-standard-2"
min_count            = 3          # 基线:BoA 约需 3 节点
max_count            = 4          # Phase 2 压测弹性,封顶 4(控成本;撞顶再原地加)
disk_size_gb         = 30
node_service_account = "sa-fintech-dev@kqeardr-gcp-shimano-internal.iam.gserviceaccount.com"
