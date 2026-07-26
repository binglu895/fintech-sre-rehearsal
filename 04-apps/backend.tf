# backend 留空,由 CI 用 -backend-config=envs/<env>/04-apps.backend.hcl 注入。
terraform {
  backend "gcs" {}
}
