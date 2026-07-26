package main

import rego.v1
import data.lib

# =====================================================================
# Cloud SQL 合规策略
# 分级说明:
#   deny  → 硬红线,违规即阻断合并(金融级不可妥协项)
#   warn  → 建议项,不阻断,提示改进(advisory,给团队缓冲)
# 每条规则带 POLICY / RATIONALE / OWNER 注释头,便于审计与交接。
#
# 环境感知(policy-as-data):
#   CI 用 `conftest test ... -d opa-data/<env>.json` 注入环境合规级别。
#   dev 环境可豁免 HA / deletion_protection(见 opa-data/dev.json)。
#   安全默认:未提供数据文件时,一律按强制处理(default enforce = true)。
# =====================================================================

# 仅当环境数据文件显式设为 false 才豁免;否则默认强制。
ha_enforced if {
	not ha_exempted
}

ha_exempted if {
	data.envcfg.enforce_ha == false
}

deletion_protection_enforced if {
	not deletion_protection_exempted
}

deletion_protection_exempted if {
	data.envcfg.enforce_deletion_protection == false
}

# ---------------------------------------------------------------------
# POLICY:     sql-high-availability
# RATIONALE:  金融账务库不可单点;REGIONAL 提供跨区主备,ZONAL 无容灾
# SEVERITY:   deny(硬红线)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 无
# ---------------------------------------------------------------------
deny contains msg if {
	ha_enforced
	some r in lib.resources_of_type(input, "google_sql_database_instance")
	r.change.after.settings.availability_type != "REGIONAL"
	msg := sprintf("[deny] Cloud SQL %v 必须为 REGIONAL 高可用(当前非 REGIONAL)", [r.address])
}

# ---------------------------------------------------------------------
# POLICY:     sql-deletion-protection
# RATIONALE:  防止误删账务库导致数据与业务不可逆丢失
# SEVERITY:   deny(硬红线)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 无
# ---------------------------------------------------------------------
deny contains msg if {
	deletion_protection_enforced
	some r in lib.resources_of_type(input, "google_sql_database_instance")
	r.change.after.deletion_protection != true
	msg := sprintf("[deny] Cloud SQL %v 必须开启 deletion_protection", [r.address])
}

# ---------------------------------------------------------------------
# POLICY:     sql-no-public-ip
# RATIONALE:  核心库禁止暴露公网,仅允许 VPC 私有连接,收窄攻击面
# SEVERITY:   deny(硬红线)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 无
# ---------------------------------------------------------------------
deny contains msg if {
	some r in lib.resources_of_type(input, "google_sql_database_instance")
	r.change.after.settings.ip_configuration.ipv4_enabled == true
	msg := sprintf("[deny] Cloud SQL %v 禁止公网 IP(ipv4_enabled 须为 false)", [r.address])
}

# ---------------------------------------------------------------------
# POLICY:     sql-pitr-recommended
# RATIONALE:  建议开启时间点恢复(PITR),便于精确回滚;非强制
# SEVERITY:   warn(建议项,advisory,不阻断)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 低敏感度实例可豁免
# ---------------------------------------------------------------------
warn contains msg if {
	some r in lib.resources_of_type(input, "google_sql_database_instance")
	backup := r.change.after.settings.backup_configuration
	backup.point_in_time_recovery_enabled != true
	msg := sprintf("[warn] Cloud SQL %v 建议开启 point_in_time_recovery(PITR)", [r.address])
}

# ---------------------------------------------------------------------
# POLICY:     sql-ssl-enforced
# RATIONALE:  建议强制加密连接(ssl_mode = ENCRYPTED_ONLY)
# SEVERITY:   warn(建议项)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 无
# ---------------------------------------------------------------------
warn contains msg if {
	some r in lib.resources_of_type(input, "google_sql_database_instance")
	ipcfg := r.change.after.settings.ip_configuration
	ipcfg.ssl_mode != "ENCRYPTED_ONLY"
	msg := sprintf("[warn] Cloud SQL %v 建议 ssl_mode 设为 ENCRYPTED_ONLY", [r.address])
}
