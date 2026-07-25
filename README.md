# fintech-sre-rehearsal — IaC 仓库(模块化版)

## 架构
GitHub + GCP + GitHub Actions + 4 层解耦,三层核心资源改用**官方模块**。

## 目录结构
```
.
├── .github/workflows/
│   ├── gcp-fintech-iac.yml   # 主流水线:路径侦测 + DAG 分层
│   └── _layer.yml            # 子流水线:auth→init→plan→OPA→(main)apply
├── policies/gcp_sql.rego     # OPA 红线
├── 01-network/               # 官方 network 模块:VPC+子网+PSA+NAT
├── 02-core-db/               # 官方 sql-db/postgresql 模块:合规 Cloud SQL
├── 03-gke-platform/          # 官方 kubernetes-engine/private-cluster 模块
├── 04-apps/                  # 应用层(待补)
└── _opa-test/                # OPA 自测样本
```

## 使用的官方模块(已锁版本)
| 层 | 模块 | 版本约束 |
|----|------|---------|
| 01 | terraform-google-modules/network/google | ~> 18.1 |
| 01 | .../network/google//modules/private-service-access | ~> 18.1 |
| 01 | terraform-google-modules/cloud-router/google | ~> 6.0 |
| 02 | terraform-google-modules/sql-db/google//modules/postgresql | ~> 28.1 |
| 03 | terraform-google-modules/kubernetes-engine/google//modules/private-cluster | ~> 37.0 |

## 层间依赖
02/03 通过 `terraform_remote_state` 读 01 的 outputs。
必须按 01 → 02 → 03 顺序 apply。

## 前置
```bash
gcloud services enable compute.googleapis.com container.googleapis.com \
  sqladmin.googleapis.com servicenetworking.googleapis.com
```
GitHub Variables:WIF_PROVIDER / GCP_SA_EMAIL(已配)。
分支保护:各层 Job 设为 Required checks。

## 模块化说明
- 层目录 = 部署单元(root module),带 backend + 独立 state。
- 层内不再手写 compute_*/sql_* 资源,改为调用官方模块。
- 官方模块经久考验,PSA/私有集群等复杂配置由模块内部处理。
- 引入第二个环境(staging)时,只需复制层目录、改 CIDR/名称即可复用同一套模块。
