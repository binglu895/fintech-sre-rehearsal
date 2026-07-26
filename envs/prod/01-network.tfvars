# ── Prod 环境 · 01-network ──
env        = "prod"
project_id = "kqeardr-gcp-shimano-internal"
region     = "asia-northeast1"

# Prod CIDR 段:10.32.0.0 ~ 10.47.255.255
subnet_cidr   = "10.32.0.0/20"
pods_cidr     = "10.36.0.0/16"
services_cidr = "10.40.0.0/20"
