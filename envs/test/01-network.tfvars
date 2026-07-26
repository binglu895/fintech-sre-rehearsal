# ── Test 环境 · 01-network ──
env        = "test"
project_id = "kqeardr-gcp-shimano-internal"
region     = "asia-northeast1"

# Test CIDR 段:10.16.0.0 ~ 10.31.255.255
subnet_cidr   = "10.16.0.0/20"
pods_cidr     = "10.20.0.0/16"
services_cidr = "10.24.0.0/20"
