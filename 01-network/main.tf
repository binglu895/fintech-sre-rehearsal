# ============================================================
# 01-network(多环境参数化版)
#   - VPC + 子网 + 二级范围 → 官方 network 模块
#   - PSA(Cloud SQL 私有连接)→ 原生资源
#   - Cloud NAT → 官方 cloud-router 模块
# 所有资源名带 ${var.env} 前缀,单项目内 dev/test/prod 三套并存不冲突。
# ============================================================

locals {
  name_prefix = "fintech-${var.env}"
  subnet_name = "${local.name_prefix}-gke-subnet"
}

# ── VPC + 子网 + 二级范围 ──
module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 18.1"
  project_id   = var.project_id
  network_name = "${local.name_prefix}-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = local.subnet_name
      subnet_ip             = var.subnet_cidr
      subnet_region         = var.region
      subnet_private_access = "true"
    }
  ]

  secondary_ranges = {
    (local.subnet_name) = [
      { range_name = "pods", ip_cidr_range = var.pods_cidr },
      { range_name = "services", ip_cidr_range = var.services_cidr },
    ]
  }
}

# ── Private Service Access:为 Google 托管服务预留私有 IP + 建 VPC Peering ──
resource "google_compute_global_address" "psa_range" {
  project       = var.project_id
  name          = "${local.name_prefix}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = module.vpc.network_self_link
}

resource "google_service_networking_connection" "psa" {
  network                 = module.vpc.network_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}

# ── Cloud NAT:私有节点出站 ──
module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 6.0"
  name    = "${local.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = module.vpc.network_name

  nats = [{
    name = "${local.name_prefix}-nat"
  }]
}

# ── 输出供下游层引用 ──
output "network_name" {
  value = module.vpc.network_name
}

output "network_self_link" {
  value = module.vpc.network_self_link
}

output "subnetwork_name" {
  value = local.subnet_name
}

output "subnet_self_link" {
  value = module.vpc.subnets["${var.region}/${local.subnet_name}"].self_link
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}
