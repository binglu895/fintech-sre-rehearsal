package main

import rego.v1
import data.lib

# =====================================================================
# GKE 合规策略(示范策略层可扩展到多服务)
# =====================================================================

# ---------------------------------------------------------------------
# POLICY:     gke-private-nodes
# RATIONALE:  节点不得有公网 IP,收窄攻击面
# SEVERITY:   deny(硬红线)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 无
# ---------------------------------------------------------------------
deny contains msg if {
	some r in lib.resources_of_type(input, "google_container_cluster")
	pcc := r.change.after.private_cluster_config[_]
	pcc.enable_private_nodes != true
	msg := sprintf("[deny] GKE 集群 %v 必须启用 enable_private_nodes", [r.address])
}

# ---------------------------------------------------------------------
# POLICY:     gke-workload-identity
# RATIONALE:  建议启用 Workload Identity,避免节点用默认 SA 的宽权限
# SEVERITY:   warn(建议项)
# OWNER:      platform-sre@example.com
# EXCEPTIONS: 无
# ---------------------------------------------------------------------
warn contains msg if {
	some r in lib.resources_of_type(input, "google_container_cluster")
	count(r.change.after.workload_identity_config) == 0
	msg := sprintf("[warn] GKE 集群 %v 建议启用 Workload Identity", [r.address])
}
