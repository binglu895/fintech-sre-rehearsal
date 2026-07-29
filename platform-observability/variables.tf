# ============================================================
# platform-observability 变量
# 值由 envs/<env>/platform-observability.tfvars 注入。
# 平台层(可观测性)独立于业务 IaC(01–04)管理。
# ============================================================

variable "env" {
  type        = string
  description = "环境标识:dev / test / prod(决定告警/看板 scope 的集群名 fintech-<env>-gke)。"
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

variable "notification_email" {
  type        = string
  description = "告警通知邮箱(on-call)。演练用个人邮箱;生产应接团队邮件组或 PagerDuty。"
}

variable "app_namespace" {
  type        = string
  description = "被监控应用所在命名空间(Bank of Anthos 默认 default)。"
  default     = "default"
}

variable "cpu_saturation_threshold" {
  type        = number
  description = "容器 CPU 饱和告警阈值(占 request 的比例)。HPA 目标 0.6,0.8 表示接近撑不住。"
  default     = 0.8
}

variable "node_saturation_threshold" {
  type        = number
  description = "节点 CPU 饱和告警阈值(占 allocatable 的比例)。撞顶说明该加节点/已撞节点池 max。"
  default     = 0.85
}

variable "restart_threshold" {
  type        = number
  description = "5 分钟内容器重启次数告警阈值(疑似 crashloop)。"
  default     = 2
}
