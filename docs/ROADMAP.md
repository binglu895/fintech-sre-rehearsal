# fintech-sre-rehearsal — 进度台账 & 后续实验规划

> 本文是可读版记录（不依赖 gh）。GitHub Issues 版见 [`scripts/create-issues.sh`](../scripts/create-issues.sh)。
> 更新日期：2026-07-26

---

## 一、已完成（Phase 1 + 工程完善）

### Phase 1：金融级 CI/CD 与 IaC 自动化门禁 — ✅ 基本收官

| Step | 内容 | 状态 |
|---|---|---|
| 1 | **WIF 无钥认证**：WIF Pool/Provider + 3 套 SA（dev/test/prod）+ 仓库级绑定 | ✅ 真部署验证 |
| 2 | **GCS 状态隔离**：3 桶（每环境一个）+ 版本控制 + 统一访问 + 12 个 state 路径 | ✅（CMEK 暂缓）|
| 3 | **环境感知 OPA**：三红线（REGIONAL/删除保护/无公网IP）+ policy-as-data（dev 宽松、test·prod 严格、无数据默认强制）| ✅ opa 二进制验证 |
| 4 | **DAG 分层 + 三环境晋升链**：paths-filter + WIF + conftest + Checkov + Environment 审批 | ✅ |
| 5 | **首次落地 + HA 配置验收**：dev + test 端到端真部署 | ✅ |

**三环境晋升链已端到端验证**：
```
push develop → Dev（自动，OPA 宽松）
PR → main    → test+prod plan（greenfield 守卫已处理冷启动）
push main    → Test（自动部署）→ test_complete → Prod（卡 production-apply 审批）
```

**HA 说明**：Phase 1 只验 HA **配置**（REGIONAL + 跨区 secondaryZone）。failover **行为**测试（RPO=0/RTO<60s）属 Phase 4，需应用+流量。

### 工程完善（Phase 1 之外的额外成果）

| 成果 | 提交 | 说明 |
|---|---|---|
| 手动 apply/destroy 独立 workflow | — | 与主流水线解耦；apply/destroy 均支持 **ALL**（正序/逆序一键）|
| **Greenfield 守卫** | `6849709` | 上游未部署时下游 plan 从 fail 转 skip，优雅处理分层冷启动 |
| **Provider 缓存** | `501331d` | 三个 workflow 缓存 provider，省每次 init 下载 |
| destroy ALL 逆序一键 | `2781f8d` | 04→03→02→01 一次删完 |
| 成本优化 | — | dev/test 单区小机型；SQL 降规格 |
| 踩通真实企业 org policy | — | VPC Flow Logs 强制、SA 创建限制 |
| 一键脚本 | — | `bootstrap.sh`（GCP 前置）、`create-issues.sh`（issue 台账）|

---

## 二、待办 Backlog

### A. Phase 1 收尾（剩余）
- **A3【P0·前置】Bank of Anthos 落地到 GKE** —— Phase 2-6 总前置（详见第三部分）
- A4【P1】main 分支保护补 Required status checks
- A5【P2】CMEK 状态桶加密（用户暂缓）

### B. 流水线 / IaC 工程完善
- B1【P1】PR 自动评论 terraform plan 结果
- B2【P1】Checkov 结果上传 GitHub Security (SARIF)
- B3【P1】GKE 专用节点 SA（最小权限，替代复用部署 SA）
- B4【P2】CI 加 terraform fmt/validate/tflint
- B5【P2】部署通知（Slack/钉钉）
- B6【P2】预置更多 org policy 合规（Shielded VM/OS Login…）
- B7【P2】GCP 预算告警 / 成本护栏
- B8【P3】staging 环境扩展 demo
- B9【P1】应用连 Cloud SQL：Secret Manager + Workload Identity（A3 配套）
- B10【P3】workflow_dispatch 输入定义需同步 main 才在 UI 生效（流程约定，或研究 Terraform Stacks/Terragrunt 迁移消除 greenfield 尖角）
- **B11【P2】destroy 的 PSA 拆除健壮化** —— 见下方"已知坑"。Cloud SQL 删除后 PSA 连接释放慢（20-30min+），
  `terraform destroy 01-network` 报 `Producer services still using this connection`，无强制手段。
  改进方向：① destroy 失败时自动 fallback 到 `gcloud compute networks peerings delete` 强删底层 peering；
  ② 或把 servicenetworking connection 移出 terraform（out-of-band 管理）；③ 或加带耐心的重试。

---

## 三、后续实验规划（Phase 2-6）

> **关键前置**：A3（Bank of Anthos 落地）必须先做——没有真实运行的应用，压测/混沌/灾备/DDoS 都无从测起对程序的影响。

### 🅰️ A3：Bank of Anthos 落地（前置，最优先）

| 项 | 内容 |
|---|---|
| **目标** | 把 Bank of Anthos 微服务部署到现有 GKE，账本/账户库接现有 Cloud SQL |
| **前置** | GKE(03) + Cloud SQL(02) 已就绪 |
| **步骤** | ① 04-apps 层用 kubernetes/helm 部署 BoA manifests<br>② 改 BoA 配置：accounts-db/ledger-db 指向 Cloud SQL（替换内置 postgres）<br>③ Secret Manager + Workload Identity 让 pod 安全取库凭证（B9）<br>④ 暴露前端（Ingress/LoadBalancer）|
| **工具** | kubectl / helm / Bank of Anthos 官方 manifests |
| **验收** | 前端可访问；注册/登录/转账/账本流程跑通；数据落 Cloud SQL |
| **风险** | BoA 默认内置 DB，改接 Cloud SQL 要改 manifests/env；WI 绑定 KSA↔GSA |
| **配套 IaC 改动** | 02 层可能加 BoA 所需的库/用户；04 层从空壳变实体 |

### Phase 2：🚀 流量激增与扩容

| 项 | 内容 |
|---|---|
| **场景** | 银行大促/秒杀，流量暴增 20 倍 |
| **前置** | A3 |
| **步骤** | ① JMeter 对前端/转账 API 施压<br>② 观察 GKE HPA（Pod 水平扩容）<br>③ GKE 节点自动扩容（cluster autoscaler / node auto-provisioning）<br>④ Cloud SQL 加只读副本，验证读写分离 |
| **IaC 改动** | 03 层开 autoscaler；BoA 服务配 HPA；02 层加 `read_replica` |
| **验收** | P99<500ms、扩容生效<2min、不宕机 |

### Phase 3：💥 混沌工程与爆炸半径

| 项 | 内容 |
|---|---|
| **场景** | 微服务崩溃 / 误改配置 / 误删 state |
| **前置** | A3 |
| **步骤** | ① 装 Chaos Mesh<br>② 杀非核心服务（contacts/userservice）pod、注入延迟/网络分区<br>③ 模拟某层 state 误操作<br>④ 验证核心转账（ledger-writer）+ Cloud SQL 账本零受损 |
| **工具** | Chaos Mesh |
| **验收** | 爆炸半径隔离，核心零受损，跨状态引用不宕机 |

### Phase 4：⚡ 灾备与高可用（真正测 HA）

| 项 | 内容 |
|---|---|
| **场景** | 单可用区完全瘫痪 |
| **前置** | A3 + REGIONAL 环境（test/prod）|
| **步骤** | ① 应用 + JMeter 持续转账流量<br>② `gcloud sql instances failover ledger-db-<env>` 强制主备切换<br>③ 隔离一个 GKE zone（cordon/drain 或删该 zone 节点）<br>④ 测量 RTO（应用重试恢复秒数）/ RPO（是否丢账）|
| **工具** | gcloud sql failover / kubectl cordon-drain |
| **验收** | RPO=0（账本零丢）、RTO<60s、应用重试自动恢复 |
| **说明** | 这才是"真正测 HA"——有业务、有流量、看得见对程序的影响 |

### Phase 5：🛡️ 零信任与抗 DDoS

| 项 | 内容 |
|---|---|
| **场景** | 黑客攻击 / SQL 注入 / DDoS |
| **前置** | A3 |
| **步骤** | ① Ingress 前挂 Cloud Armor（WAF + DDoS 规则）<br>② 启用 Anthos Service Mesh (ASM) mTLS 零信任<br>③ 模拟恶意 IP / SQL 注入<br>④ 验证边缘拦截 + 服务间未授权 403 |
| **IaC 改动** | 加 Cloud Armor security policy；03/04 层引入 ASM |
| **验收** | 恶意 IP 边缘秒级熔断、未授权服务间访问 403 |

### Phase 6：📦 开发者平台与新产品上线

| 项 | 内容 |
|---|---|
| **场景** | 新微服务（个人理财）一键入驻 |
| **前置** | A3 + 成熟 CI/CD |
| **步骤** | ① 部署 Backstage IDP<br>② 做 software template：网页填表 → 生成新服务骨架 + PR → CI/CD 注入 GKE<br>③ 上线新服务，核心业务无感 |
| **工具** | Backstage |
| **验收** | 零命令行、零合规漏洞、现有核心转账 0 停机 |

---

## 四、实验推进建议顺序

```
A3 Bank of Anthos 落地(前置)
   │
   ├─ Phase 2 压测扩容(需先配 HPA/autoscaler/只读副本)
   ├─ Phase 3 混沌(装 Chaos Mesh)
   ├─ Phase 4 灾备(应用+流量下真测 failover)   ← 关闭 Phase 1 遗留的"HA行为测试"
   ├─ Phase 5 零信任(Cloud Armor + ASM)
   └─ Phase 6 开发者平台(Backstage)
```

**每个 Phase 都会带来对应的 IaC 改动**（Phase 2 的 HPA/autoscaler/只读副本、Phase 5 的 Cloud Armor/ASM 等），正好继续锻炼这套三环境流水线——**先在 dev 迭代验证，再走晋升链上 test/prod**。

---

## 五、日常迭代提醒

- **workflow_dispatch 的输入定义**（apply/destroy 的 env/layer 等）改完要**合并到 main** 才在 UI 下拉框生效（表单认默认分支）。
- 日常层代码/逻辑迭代可留 develop，靠 PR 的 test/prod plan 兜底。
- 只改要测的层 → detect 只跑那层 → 增量更新，别每次 ALL 重建。
- 演练用完即毁：`gcp-fintech-destroy` env=<env> layer=ALL confirm=DESTROY。

---

## 六、已知坑 & Runbook

### PSA 拆除卡死（destroy 01-network 报 "Producer services still using this connection"）

**现象**：destroy 时 GKE/SQL 都删成功，卡在 `01-network` 的 `google_service_networking_connection`。
即使 Cloud SQL 已删，GCP 后端释放 PSA 连接需 20-30min+，期间 servicenetworking 一直标记"in use"，无强制删除手段。

**手动强删 runbook（已验证有效）**——直接删底层 compute VPC peering，绕过 servicenetworking 的 in-use 检查：

```bash
PROJECT=kqeardr-gcp-shimano-internal
ENV=test   # 或 dev

# 0. 先确认 SQL 已删(安全前提)
gcloud sql instances list --project=$PROJECT --filter="name~ledger-db-$ENV"

# 1. 直接删 VPC peering(绕过 in-use 检查)
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=fintech-$ENV-vpc --project=$PROJECT

# 2. 删保留的 PSA 全局地址
gcloud compute addresses delete fintech-$ENV-psa-range --global --project=$PROJECT

# 3. 删 VPC
gcloud compute networks delete fintech-$ENV-vpc --project=$PROJECT

# 4.(可选)重跑 destroy 01-network 对账清空 stale state
```

**改进项**：见 backlog B11。
