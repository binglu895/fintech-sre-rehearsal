# ============================================================
# 01-network(模块化修正版)
#   - VPC + 子网 + 二级范围 → 官方 network 模块
#   - PSA(Cloud SQL 私有连接)→ 原生资源(参数明确,避免子模块版本差异)
#   - Cloud NAT → 官方 cloud-router 模块
# ============================================================

# ── VPC + 子网 + 二级范围 ──
module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 18.1"
  project_id   = var.project_id
  network_name = "fintech-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "fintech-vpc-gke-subnet"
      subnet_ip             = "10.10.0.0/20"
      subnet_region         = var.region
      subnet_private_access = "true"
    }
  ]

  secondary_ranges = {
    "fintech-vpc-gke-subnet" = [
      { range_name = "pods", ip_cidr_range = "10.20.0.0/16" },
      { range_name = "services", ip_cidr_range = "10.30.0.0/20" },
    ]
  }
}

# ── Private Service Access:为 Google 托管服务预留私有 IP + 建 VPC Peering ──
resource "google_compute_global_address" "psa_range" {
  project       = var.project_id
  name          = "fintech-vpc-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
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
  name    = "fintech-vpc-router"
  project = var.project_id
  region  = var.region
  network = module.vpc.network_name

  nats = [{
    name = "fintech-vpc-nat"
  }]
}

# ── 输出供下游层引用 ──
output "network_name" {
  value = module.vpc.network_name
}

output "network_self_link" {
  value = module.vpc.network_self_link
}

output "subnet_self_link" {
  value = module.vpc.subnets["${var.region}/fintech-vpc-gke-subnet"].self_link
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}
# test branch flow Sat Jul 25 18:40:27     2026
# test branch flow Sat Jul 25 18:44:48     2026
# PR round2 Sat Jul 25 18:57:42     2026
