# ============================================================
# 02-core-db(多环境参数化):官方 sql-db//modules/postgresql(~> 28.x)
# 满足 OPA 红线:REGIONAL(test/prod)/ deletion_protection / 无公网 IP
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

module "postgresql" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 28.1"

  project_id       = var.project_id
  name             = "ledger-db-${var.env}"
  database_version = "POSTGRES_15"
  region           = var.region
  tier             = var.tier

  availability_type   = var.availability_type   # 红线①(dev 环境可豁免为 ZONAL)
  deletion_protection = var.deletion_protection  # 红线②(dev 环境可豁免为 false)

  # 红线③:无公网 IP + 私有连接指向 01 层 VPC
  ip_configuration = {
    ipv4_enabled        = false
    private_network     = data.terraform_remote_state.network.outputs.network_self_link
    ssl_mode            = "ENCRYPTED_ONLY"
    allocated_ip_range  = null
    authorized_networks = []
  }

  maintenance_window_day          = 7 # 周日
  maintenance_window_hour         = 3
  maintenance_window_update_track = "stable"

  backup_configuration = {
    enabled                        = true
    start_time                     = "03:00"
    location                       = var.region
    point_in_time_recovery_enabled = true
    transaction_log_retention_days = 7
    retained_backups               = 7
    retention_unit                 = "COUNT"
  }
}

output "instance_connection_name" {
  value = module.postgresql.instance_connection_name
}

output "private_ip_address" {
  value = module.postgresql.private_ip_address
}
