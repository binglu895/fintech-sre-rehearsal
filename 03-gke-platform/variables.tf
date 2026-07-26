# ============================================================
# 03-gke-platform 变量(多环境参数化)
# 值由 envs/<env>/03-gke-platform.tfvars 注入。
# ============================================================

variable "env" {
  type        = string
  description = "环境标识:dev / test / prod。"
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env 必须是 dev / test / prod 之一。"
  }
}

variable "project_id" {
  type        = string
  description = "GCP 项目 ID。"
}

variable "region" {
  type        = string
  description = "GCP region。"
  default     = "asia-northeast1"
}

variable "state_bucket" {
  type        = string
  description = "本环境的 GCS state 桶,用于读取 01-network 的 remote_state。"
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "GKE 控制平面 /28 CIDR。单项目内各环境须不同,避免 peering 冲突。"
}

variable "regional" {
  type        = bool
  description = "true=区域级集群(节点跨 3 可用区,贵);false=单区集群(省成本,dev/test 用)。"
  default     = true
}

variable "zones" {
  type        = list(string)
  description = "节点可用区。zonal 时取第一个;regional 传空列表则自动跨区。"
  default     = ["asia-northeast1-a"]
}

variable "node_service_account" {
  type        = string
  description = "节点绑定的 SA。复用环境部署 SA,避免模块新建 SA(需 serviceAccounts.create 权限)。"
}

variable "disk_size_gb" {
  type        = number
  description = "节点磁盘大小 GB。dev 可调小省成本。"
  default     = 50
}

variable "machine_type" {
  type        = string
  description = "节点机型。dev 可用 e2-standard-2 省钱。"
  default     = "e2-standard-4"
}

variable "min_count" {
  type        = number
  description = "节点池最小节点数。"
  default     = 1
}

variable "max_count" {
  type        = number
  description = "节点池最大节点数。"
  default     = 3
}
