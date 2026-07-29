# ============================================================
# 04-apps(应用层 IAM):Bank of Anthos 的 Workload Identity 身份
# B12 codify:之前由 connect-boa-cloudsql.sh 用 gcloud 建,现纳入 terraform。
#
# 边界说明:
#   - 进 terraform:GSA + IAM 角色 + WI 绑定(基础设施/身份,声明式最合适)
#   - 不进 terraform:BoA 应用 manifests + KSA + secret(走 kubectl/GitOps + Secret Manager)
# ============================================================

locals {
  # GSA 单项目内需按 env 区分(避免 dev/test/prod 撞名);KSA 是每集群资源,同名无妨。
  boa_gsa_id    = "boa-gsa-${var.env}"
  boa_ksa       = "boa-ksa"
  boa_namespace = "default"
}

# BoA 用的 Google 服务账号
resource "google_service_account" "boa" {
  project      = var.project_id
  account_id   = local.boa_gsa_id
  display_name = "Bank of Anthos (${var.env})"
}

# 授权:连 Cloud SQL + trace + monitoring(最小权限,对齐 BoA 官方)
resource "google_project_iam_member" "boa" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/cloudtrace.agent",
    "roles/monitoring.metricWriter",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.boa.email}"
}

# Workload Identity:允许 GKE 的 KSA(default/boa-ksa)模拟该 GSA。
# 注:KSA 本身 + 注解由应用侧(kubectl/manifest)创建,这里只声明 IAM 绑定(引用 principal 字符串,无需 KSA 先存在)。
resource "google_service_account_iam_member" "boa_wi" {
  service_account_id = google_service_account.boa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.boa_namespace}/${local.boa_ksa}]"
}

output "boa_gsa_email" {
  value = google_service_account.boa.email
}
