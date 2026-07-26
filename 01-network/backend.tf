# backend 配置留空,由 CI 用 -backend-config=envs/<env>/01-network.backend.hcl 动态注入。
# 这样同一份代码可对接 dev/test/prod 三个独立 state 桶。
terraform {
  backend "gcs" {}
}
