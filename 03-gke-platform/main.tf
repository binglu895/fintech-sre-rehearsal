# ============================================================
# 03-gke-platform(模块化):官方 kubernetes-engine//modules/private-cluster
# 私有集群 + Workload Identity,挂 01-network 的子网和二级范围。
# ============================================================

variable "project_id" {
  type    = string
  default = "kqeardr-gcp-shimano-internal"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = "fintech-iac-states-prod"
    prefix = "network/state"
  }
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 37.0"

  project_id = var.project_id
  name       = "fintech-gke"
  region     = var.region
  regional   = true

  # 挂 01-network 的网络(用 network_name / subnet 名,模块内部按 project+region 解析)
  network           = data.terraform_remote_state.network.outputs.network_name
  subnetwork        = "fintech-vpc-gke-subnet"
  ip_range_pods     = data.terraform_remote_state.network.outputs.pods_range_name
  ip_range_services = data.terraform_remote_state.network.outputs.services_range_name

  # 私有集群:节点无公网 IP
  enable_private_nodes    = true
  enable_private_endpoint = false # 控制平面保留公网端点便于管理;true 需堡垒机
  master_ipv4_cidr_block  = "172.16.0.0/28"

  # Workload Identity(pull 式 GitOps 前提)
  identity_namespace = "${var.project_id}.svc.id.goog"

  # 节点池
  node_pools = [
    {
      name         = "primary-pool"
      machine_type = "e2-standard-4"
      min_count    = 1
      max_count    = 3
      disk_size_gb = 50
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
