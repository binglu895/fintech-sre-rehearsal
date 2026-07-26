# ============================================================
# 03-gke-platform(多环境参数化):官方 kubernetes-engine//modules/private-cluster
# 私有集群 + Workload Identity,挂 01-network 的子网和二级范围。
# 子网名从 01 层 remote_state 读取(已带 env 前缀),不再写死。
# ============================================================

locals {
  name_prefix = "fintech-${var.env}"
}

data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "network/state"
  }
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 37.0"

  project_id = var.project_id
  name       = "${local.name_prefix}-gke"
  region     = var.region
  regional   = var.regional
  zones      = var.zones

  # 复用现有 SA 作节点身份,避免模块新建 SA(需 iam.serviceAccounts.create)
  create_service_account = false
  service_account        = var.node_service_account

  # 挂 01-network 的网络(名称从 remote_state 读取,已带 env 前缀)
  network           = data.terraform_remote_state.network.outputs.network_name
  subnetwork        = data.terraform_remote_state.network.outputs.subnetwork_name
  ip_range_pods     = data.terraform_remote_state.network.outputs.pods_range_name
  ip_range_services = data.terraform_remote_state.network.outputs.services_range_name

  # 私有集群:节点无公网 IP
  enable_private_nodes    = true
  enable_private_endpoint = false # 控制平面保留公网端点便于管理;true 需堡垒机
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block

  # Workload Identity(pull 式 GitOps 前提)
  identity_namespace = "${var.project_id}.svc.id.goog"

  # 节点池
  node_pools = [
    {
      name         = "primary-pool"
      machine_type = var.machine_type
      min_count    = var.min_count
      max_count    = var.max_count
      disk_size_gb = var.disk_size_gb
      disk_type    = "pd-standard"
      auto_repair  = true
      auto_upgrade = true
    }
  ]

  remove_default_node_pool = true
  deletion_protection      = false # 演练环境
}

output "cluster_name" {
  value = module.gke.name
}

output "cluster_endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}
