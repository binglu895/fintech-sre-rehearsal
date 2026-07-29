# ============================================================
# 02-core-db 变量(多环境参数化)
# 值由 envs/<env>/02-core-db.tfvars 注入。
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

variable "tier" {
  type        = string
  description = "Cloud SQL 机型。dev 可用小规格省钱,prod 用大规格。"
  default     = "db-custom-2-8192"
}

variable "availability_type" {
  type        = string
  description = "REGIONAL(高可用)/ ZONAL(单点)。dev=ZONAL,test/prod=REGIONAL。"
  default     = "REGIONAL"
}

variable "deletion_protection" {
  type        = bool
  description = "删除保护。dev=false 便于反复演练,prod=true。destroy workflow 会临时覆盖为 false。"
  default     = true
}

variable "boa_db_password" {
  type        = string
  description = "Bank of Anthos 数据库 admin 用户密码。demo=admin(匹配 BoA 内置 config);生产应走 Secret Manager(B9)。"
  default     = "admin"
  sensitive   = true
}
