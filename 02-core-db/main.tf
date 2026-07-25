# ============================================================
# 02-core-db(模块化):官方 sql-db//modules/postgresql(~> 28.x)
# 满足 OPA 三条红线:REGIONAL / deletion_protection / 无公网 IP
# 字段严格对齐官方 28.x 示例。
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

module "postgresql" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 28.1"

  project_id       = var.project_id
  name             = "ledger-db-prod"
  database_version = "POSTGRES_15"
  region           = var.region
  tier             = "db-custom-2-8192"

  availability_type   = "REGIONAL" # 红线①
  deletion_protection = true       # 红线②

  # 红线③:无公网 IP + 私有连接指向 01 层 VPC
  ip_configuration = {
    ipv4_enabled        = false
    private_network     = data.terraform_remote_state.network.outputs.network_self_link
    ssl_mode            = "ENCRYPTED_ONLY"
    allocated_ip_range  = null
    authorized_networks = []
  }

  # 维护窗口(平铺参数,非嵌套块)
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
