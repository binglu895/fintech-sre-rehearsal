# ============================================================
# 01-network 变量(多环境参数化)
# 所有值由 envs/<env>/01-network.tfvars 注入,不再写死 default。
# 单 GCP 项目内靠 env 前缀 + CIDR 分段模拟 dev/test/prod 三环境。
# ============================================================

variable "env" {
  type        = string
  description = "环境标识:dev / test / prod。用于资源命名前缀,保证单项目内不冲突。"
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env 必须是 dev / test / prod 之一。"
  }
}

variable "project_id" {
  type        = string
  description = "GCP 项目 ID。当前三环境共用同一项目;未来拆项目时只改此值。"
}

variable "region" {
  type        = string
  description = "GCP region。"
  default     = "asia-northeast1"
}

variable "subnet_cidr" {
  type        = string
  description = "GKE 节点子网主 CIDR(各环境分段,避免重叠)。"
}

variable "pods_cidr" {
  type        = string
  description = "GKE Pod 二级范围 CIDR。"
}

variable "services_cidr" {
  type        = string
  description = "GKE Service 二级范围 CIDR。"
}

variable "psa_prefix_length" {
  type        = number
  description = "Private Service Access 预留地址块前缀长度。"
  default     = 16
}
