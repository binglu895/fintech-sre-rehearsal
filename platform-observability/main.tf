# ============================================================
# platform-observability — 平台层可观测性(Cloud Operations Suite via Terraform)
#
# 选型:Cloud Ops Suite(原生托管)+ 后续 GMP/OTel 补应用级信号。
#   理由:零运维、与 GKE/Cloud SQL 原生集成、IaC 可管、数据留在项目内(合规)。
#
# 本层产出(告警驱动演练的"发现机制"):
#   ① 邮件通知渠道(on-call)
#   ② 告警:容器 CPU 饱和 / 节点 CPU 饱和 / 容器重启(crashloop)
#   ③ 黄金信号看板(饱和度 + 错误)
#
# 黄金信号缺口:Latency/Traffic/Errors(应用级)在 L4 LoadBalancer 下拿不到,
#   需 GMP 抓 BoA Prometheus 指标 + OTel 埋点补齐(Phase 5,配 L7 Ingress)。见 docs/OBSERVABILITY.md。
#
# 独立管理:自有 workflow(platform-observability.yml)+ 自有 state,不进业务流水线。
# ============================================================

locals {
  cluster_name = "fintech-${var.env}-gke"
  # Monitoring v3 过滤语法:resource.label.<key>(单数)
  container_scope = "resource.type=\"k8s_container\" AND resource.label.cluster_name=\"${local.cluster_name}\" AND resource.label.namespace_name=\"${var.app_namespace}\""
  node_scope      = "resource.type=\"k8s_node\" AND resource.label.cluster_name=\"${local.cluster_name}\""
}

# ── ① 邮件通知渠道 ──
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "[fintech-${var.env}] SRE on-call (email)"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }
}

# ── ②a 容器 CPU 饱和(Saturation)──
resource "google_monitoring_alert_policy" "container_cpu_saturation" {
  project      = var.project_id
  display_name = "[fintech-${var.env}] 容器 CPU 饱和"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "容器 CPU request utilization > ${var.cpu_saturation_threshold}"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/cpu/request_utilization\" AND ${local.container_scope}"
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_saturation_threshold
      duration        = "120s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.container_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "容器 CPU 使用超过请求的 ${var.cpu_saturation_threshold}(HPA 目标 0.6)。突发流量下 HPA 应正在横向扩容;若持续不回落,检查是否撞 HPA maxReplicas 或节点池 max_count。Runbook: docs/OBSERVABILITY.md"
  }
}

# ── ②b 节点 CPU 饱和(容量/自动扩容信号)──
resource "google_monitoring_alert_policy" "node_cpu_saturation" {
  project      = var.project_id
  display_name = "[fintech-${var.env}] 节点 CPU 饱和"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "节点 CPU allocatable utilization > ${var.node_saturation_threshold}"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\" AND ${local.node_scope}"
      comparison      = "COMPARISON_GT"
      threshold_value = var.node_saturation_threshold
      duration        = "180s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.node_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "节点 CPU 逼近可分配上限。Cluster Autoscaler 应正在加节点;若已撞节点池 max_count(dev=4),需评估扩容护栏或纵向换更大机型。Runbook: docs/OBSERVABILITY.md"
  }
}

# ── ②c 容器重启 / crashloop(Errors)──
resource "google_monitoring_alert_policy" "pod_restart" {
  project      = var.project_id
  display_name = "[fintech-${var.env}] 容器重启(疑似 crashloop)"
  combiner     = "OR"
  severity     = "ERROR"

  conditions {
    display_name = "5 分钟内容器重启 > ${var.restart_threshold}"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/restart_count\" AND ${local.container_scope}"
      comparison      = "COMPARISON_GT"
      threshold_value = var.restart_threshold
      duration        = "0s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.container_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "容器在 5 分钟内重启多次,疑似 crashloop(OOM / 探针失败 / 依赖不可用)。kubectl describe pod + kubectl logs --previous 定位。Runbook: docs/OBSERVABILITY.md"
  }
}

# ── ③ 黄金信号看板 ──
resource "google_monitoring_dashboard" "golden_signals" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "[fintech-${var.env}] SRE 黄金信号 · Bank of Anthos"
    gridLayout = {
      columns = "2" # int64 字段在 GCP API JSON 中以字符串表示
      widgets = [
        {
          title = "饱和度 · 容器 CPU (request utilization)"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/cpu/request_utilization\" AND ${local.container_scope}"
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["resource.label.container_name"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "饱和度 · 容器内存 (request utilization)"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/memory/request_utilization\" AND ${local.container_scope}"
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["resource.label.container_name"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "容量 · 节点 CPU (allocatable utilization)"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\" AND ${local.node_scope}"
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["resource.label.node_name"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "错误 · 容器重启次数 (5m delta)"
          xyChart = {
            dataSets = [{
              plotType = "STACKED_BAR"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/restart_count\" AND ${local.container_scope}"
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.container_name"]
                  }
                }
              }
            }]
          }
        },
      ]
    }
  })
}

output "notification_channel" {
  value       = google_monitoring_notification_channel.email.id
  description = "邮件通知渠道资源名。"
}

output "alert_policies" {
  value = [
    google_monitoring_alert_policy.container_cpu_saturation.name,
    google_monitoring_alert_policy.node_cpu_saturation.name,
    google_monitoring_alert_policy.pod_restart.name,
  ]
  description = "已创建的告警策略资源名。"
}

output "dashboard_id" {
  value       = google_monitoring_dashboard.golden_signals.id
  description = "黄金信号看板 ID(控制台 Monitoring → Dashboards 可见)。"
}
