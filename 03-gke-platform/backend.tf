# backend 留空,由 CI 用 -backend-config=envs/<env>/03-gke-platform.backend.hcl 注入。
terraform {
  backend "gcs" {}
}
