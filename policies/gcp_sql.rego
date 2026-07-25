package main

# ── Cloud SQL 高可用:必须跨区主备(REGIONAL),禁止单点(ZONAL) ──
deny[msg] {
  r := input.resource_changes[_]
  r.type == "google_sql_database_instance"
  r.change.after.settings.availability_type != "REGIONAL"
  msg := sprintf("Cloud SQL %v 必须为 REGIONAL 高可用", [r.address])
}

# ── 删库防爆:必须开启 deletion_protection ──
deny[msg] {
  r := input.resource_changes[_]
  r.type == "google_sql_database_instance"
  r.change.after.deletion_protection != true
  msg := sprintf("Cloud SQL %v 必须开启 deletion_protection", [r.address])
}

# ── 网络隔离:禁止公网 IP ──
deny[msg] {
  r := input.resource_changes[_]
  r.type == "google_sql_database_instance"
  r.change.after.settings.ip_configuration.ipv4_enabled == true
  msg := sprintf("Cloud SQL %v 禁止公网 IP", [r.address])
}
