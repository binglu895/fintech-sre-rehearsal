# ============================================================
# 01-network(模块化):使用官方 terraform-google-modules/network
#   - VPC + 子网 + 二级范围        → network 模块主体
#   - Private Service Access(PSA) → private-service-access 子模块
#   - Cloud NAT                    → cloud-nat 子模块
# 官方模块经久考验,替代自研 compute_* 资源 
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
      subnet_private_access = "true" # 私有节点访问 Google API 走私有通道
    }
  ]

  secondary_ranges = {
    "fintech-vpc-gke-subnet" = [
      { range_name = "pods", ip_cidr_range = "10.20.0.0/16" },
      { range_name = "services", ip_cidr_range = "10.30.0.0/20" },
    ]
  }
}

# ── Private Service Access:Cloud SQL 私有连接前置 ──
module "private_service_access" {
  source        = "terraform-google-modules/network/google//modules/private-service-access"
  version       = "~> 18.1"
  project_id    = var.project_id
  vpc_network   = module.vpc.network_name
  address       = "10.40.0.0"
  prefix_length = 16
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

# ── 输出供下游层(remote_state)引用 ──
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
# trigger
