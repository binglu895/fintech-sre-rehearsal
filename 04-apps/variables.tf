# ============================================================
# 04-apps 变量(应用层,待补)。目前仅参数化 provider,便于三环境统一流水线。
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
  description = "本环境的 GCS state 桶(供未来读取上游层 remote_state)。"
}
