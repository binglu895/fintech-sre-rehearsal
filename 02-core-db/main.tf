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
  # try() 防止 destroy 时 01-network state 为空导致 "outputs is object with no attributes"
  ip_configuration = {
    ipv4_enabled        = false
    private_network     = try(data.terraform_remote_state.network.outputs.network_self_link, null)
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

# ── Bank of Anthos 数据层(B12 codify)──
# 两个库 + admin 用户,之前由 connect-boa-cloudsql.sh 用 gcloud 建,现纳入 terraform 声明式管理。
# 密码:demo 用 admin;生产应走 Secret Manager(B9),届时需同步改 BoA config。
resource "google_sql_database" "boa" {
  for_each   = toset(["accounts-db", "ledger-db"])
  name       = each.key
  instance   = module.postgresql.instance_name
  project    = var.project_id
  depends_on = [module.postgresql] # 必须等实例(及模块内 db/user)建完,否则并行创建报 instance 不存在
}

resource "google_sql_user" "boa_admin" {
  name       = "admin"
  instance   = module.postgresql.instance_name
  password   = var.boa_db_password
  project    = var.project_id
  depends_on = [module.postgresql]
}

output "instance_connection_name" {
  value = module.postgresql.instance_connection_name
}

output "private_ip_address" {
  value = module.postgresql.private_ip_address
}
