# backend 留空,由 CI 用 -backend-config=envs/<env>/platform-observability.backend.hcl 注入。
# 独立 state 前缀(platform-observability/state),与业务层 01–04 完全分离。
terraform {
  backend "gcs" {}
}
