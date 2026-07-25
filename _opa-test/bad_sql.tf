# ── 故意违规示例:三条红线全踩,用于验证 OPA 能拦下 ──
# 用法见 _opa-test/README.md。这个目录不接入正式流水线,仅本地测策略用。

resource "google_sql_database_instance" "bad" {
  name             = "bad-db"
  database_version = "POSTGRES_15"
  region           = "asia-northeast1"

  deletion_protection = false # 违反红线②

  settings {
    tier              = "db-custom-2-8192"
    availability_type = "ZONAL" # 违反红线①(单点)

    ip_configuration {
      ipv4_enabled = true # 违反红线③(公网 IP)
    }
  }
}
