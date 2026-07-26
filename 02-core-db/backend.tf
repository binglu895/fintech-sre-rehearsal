# backend 留空,由 CI 用 -backend-config=envs/<env>/02-core-db.backend.hcl 注入。
terraform {
  backend "gcs" {}
}
