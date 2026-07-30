# ============================================================
# 04-apps(应用层)
#
# 说明:BoA 的身份(boa-gsa-<env> + IAM + Workload Identity 绑定)**不放这里**。
#   原因:本层由 per-env 部署 SA(sa-fintech-<env>)执行,而该 SA 是最小权限、
#         没有 iam.serviceAccounts.create / projectIamAdmin(防提权)。
#   正确归属:IAM/身份由 bootstrap.sh(特权、人工一次性)创建。见 scripts/bootstrap.sh。
#
#   保留在 terraform 的:02-core-db 的库/用户(deploy SA 有 cloudsql.admin 能建)。
#   应用 manifests / KSA / secret:走 gcp-fintech-app workflow(kubectl)。
#
# 本层目前无 terraform 资源(应用通过 workflow 部署)。
# ============================================================
