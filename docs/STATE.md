# 当前状态 & 下一步（会话交接）

> 新会话从这里接。快照日期：2026-07-30（Phase 2 演练进行中）。
> 详情：计划见 [ROADMAP.md](ROADMAP.md)，教训见 [FINDINGS.md](FINDINGS.md)，AIOps（PARKED）见 [AIOPS-ROADMAP.md](AIOPS-ROADMAP.md)，操作步骤见 [../README.md](../README.md)。

## 项目一句话
金融级 SRE 演练平台：GCP + Bank of Anthos + 三环境（dev/test/prod）CI/CD + IaC + OPA 门禁。
终极目的是在其上做 **fintech AIOps**（现 PARKED）。

## 关键常量
- PROJECT：`kqeardr-gcp-shimano-internal`，REGION：`asia-northeast1`
- Repo：`binglu895/fintech-sre-rehearsal`，默认分支 `main`，开发分支 `develop`
- 分支模型：push `develop`→Dev；push `main`→Test→Prod（晋升链）
- 用户在 **Cloud Shell** 手动跑 gcloud/kubectl；能进 pipeline 的尽量进 pipeline

## 现在的状态
- **dev 正在 destroy**（2026-07-30 会话末，成本控制）。下次从头重建（#0）。若 destroy 后 `01-network` 有网络孤儿（`fintech-dev-vpc` + `fintech-dev-psa-range`），用 FINDINGS #10 的 PSA 强删 runbook 收尾。
- **平台监控（O0）已部署过**：bootstrap 已建 `sa-fintech-platform`、2 个 GitHub 变量（`WIF_PROVIDER_PLATFORM`/`GCP_SA_EMAIL_PLATFORM`）已配、`platform-observability`(dev,apply) 跑通。告警邮件发到 `xinglu.a.chen@accenture.com`（配在 `envs/dev/platform-observability.tfvars`）。**注**：bootstrap.sh 本次修复了平台 SA 的 state 桶 objectAdmin 权限（幂等重跑会自动补）。
- **Phase 2 事件演练进行中**：场景独立管理在 `scenarios/phase2-loadtest/`（通用 workflow `gcp-fintech-scenario.yml`，参数 env/scenario/action/replicas）。已跑到"处置前基线"，**remediate 处置对比 + 清零重测未做**。详见 FINDINGS #17–22 与场景 README 复盘表。
- 共享项目里**非本项目资源**（`sql-test-instance-01`、`default` 网络、`default-ip-range` 等）**不要删**。
- 最新代码在 `develop`（含 scenarios/ + scenario workflow）；`main` 已有全部手动 workflow + 平台层文件。

## 主线：把 fintech SRE 跑完（AIOps 之前，全人工）
可观测性数据面（指标/日志/追踪）属 SRE 基本功照做，**只是先不上 AI 那层**。

| # | 事项 | 依赖 |
|---|---|---|
| 0 | **重建 dev**：`gcp-fintech-apply`(env=dev, layer=ALL) → `gcp-fintech-app`(dev, deploy) | — |
| 1 | **部署监控 O0**：bootstrap(develop) 建平台 SA + 加 2 个 GitHub 变量(README) → 跑 `platform-observability`(main, dev, apply) | 0 |
| 2 | **O1 L7 边缘信号**：frontend 换 Gateway/Ingress → P99/QPS/5xx（新 `05-ingress` 层） | 1 |
| 3 | **Phase 2 压测/扩容**：HPA + Cluster Autoscaler，告警驱动演练，填复盘表 | 2 |
| 4 | **Phase 3 混沌**：Chaos Mesh，验爆炸半径 + 账本零损 | 3 |
| 5 | **Phase 5 安全**：Cloud Armor 标准规则 + ASM mTLS | 应用在跑 |
| 6 | **Phase 4 灾备/HA**：需 **test(REGIONAL)**，SQL failover + zone drain，量 RTO/RPO | test 环境 |

架构补全（穿插）：B9 Secret Manager、PDB、B14 destroy 健壮化、B3 节点 SA、A4 分支保护、B13 populate v2 sidecar、(可选)GitOps。

## 立即下一步（下次会话）
dev 已 destroy，需先重建再继续 Phase 2：

1. **重建 dev**：`gcp-fintech-apply` env=dev layer=ALL（Branch=develop）→ `gcp-fintech-app`(dev, deploy)。若网络孤儿还在，先按 FINDINGS #10 清干净。（平台 SA/变量已配，`platform-observability`(dev,apply) 可直接重跑，无需再 bootstrap。）
2. **收尾 Phase 2 演练**（接上次断点，见 FINDINGS #21/#22）：
   - 清零重测 replicas=10：`kubectl rollout restart deployment loadgenerator` → 跑 3-5min → 读日志，验证是否收敛到 ~37%（证实/证伪饱和平台期）。
   - 执行 `remediate`（装 HPA）→ 对比处置前后 `POST /login`/`/signup` 的延迟和失败率，填场景 README 复盘表"处置后"行。
   - （可选）查 frontend/userservice 日志验证 37% 的超时成因假说。
   - （可选）给 `run.sh` 加 `reset` 动作，一键清零重测。
3. 之后进 **O1 L7 边缘信号**（表 #2），O1 后用同剧本再跑一遍，对比"资源型 vs 症状型"监控。

## AIOps（PARKED，后续逐步推进）
独立管理于 [AIOPS-ROADMAP.md](AIOPS-ROADMAP.md)。两条腿：现有 Gemini Enterprise 人辅助（$0 增量，先验证）→ Vertex AI 自主闭环（自动化时才花钱）。SRE 主线完成后再启动。
