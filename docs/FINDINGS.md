# 演练发现与经验（Findings & Lessons）

> 沉淀"教训与结论"（区别于 [ROADMAP.md](ROADMAP.md) 的进度台账）。每个 Phase 跑完追加"发现/问题/解法/验收"。
> 更新日期：2026-07-30

---

## 一、已积累经验（Phase 1 + A3 + 工程期）

### 权限 / 身份架构

**1. IAM 身份归属：identity 归 bootstrap，资源归各层（防提权）**
- 现象：把 BoA 的 GSA/IAM/WI 放进 `04-apps` terraform，apply 报 `iam.serviceAccounts.create` 403。
- 根因：per-env 部署 SA 是**最小权限**，故意没有 IAM 管理权（projectIamAdmin/serviceAccounts.create）。
- 解法：**身份类资源（GSA/角色/WI 绑定）由 `bootstrap.sh`（特权人工账号）建**；库/用户留 `02`（部署 SA 有 cloudsql.admin）；应用 manifests/KSA/secret 走 workflow。
- 结论：**"谁有权建"决定"资源归哪层"**。最小权限是特性不是障碍——别为了省事给部署 SA 加 IAM 管理权。

**2. WIF `attribute.ref` 映射坑 → 统一仓库级绑定**
- 现象：dev SA 的 ref 级绑定不匹配，`iam.serviceAccounts.getAccessToken` 被拒。
- 根因：已存在的 provider 缺 `attribute.ref` 映射；且 PR 阶段 ref=`refs/pull/N/merge`，ref 级绑定跑不了 plan。
- 解法：provider `--attribute-mapping` 补 `attribute.ref`；**所有 SA 改用仓库级 `attribute.repository` 绑定**（映射稳定）。"哪个分支能部署哪个环境"由 workflow `if` + Environment 审批保证，不靠 WIF ref。
- 结论：WIF 绑定尽量用稳定属性（repository），分支管控交给 workflow/Environment。

**3. GKE 节点 SA：复用部署 SA，别让模块新建**
- 现象：private-cluster 模块默认新建节点 SA → `iam.serviceAccounts.create` 403。
- 解法：`create_service_account=false` + `service_account=<部署 SA>`。（最小权限版见 backlog B3）

### Terraform / 模块

**4. Provider 版本按层收敛**
- google `~>5` vs sql-db 需 `>=7.22`、kubernetes-engine 需 `>=6.38,<7` 冲突。
- 解法：每层 provider.tf 单独钉：`02`→`>=7.22,<8`+google-beta；`03`→`>=6.38,<7`。

**5. 库/用户与实例的删除顺序竞争**
- 现象：destroy 02 时 `google_sql_user.boa_admin` 报 `role "admin" cannot be dropped, objects depend on it`。
- 根因：admin 拥有 BoA 灌进 accounts-db 的对象；用户删除与库删除**并行**，用户删时库还没删完。
- 解法：靠 destroy 的 90s 重试（库删完后 admin 无依赖对象即可删）。根治见 backlog（给用户/库加删除顺序约束）。

**6. `machine_type` 是 ForceNew → 改机型重建节点池**
- 改 `03` 的 machine_type 触发节点池重建（滚动升级，surge 出临时节点后收敛到目标）；pod 重调度，Cloud SQL 数据不受影响。

### 组织策略 / 容量

**7. 企业 org policy 会拦你**
- `constraints/compute.requireVpcFlowLogs`（Error 412）→ 子网必须开 flow logs。
- `iam.serviceAccounts.create` 受限 → 见经验 1/3。

**8. BoA 容量：e2-medium 共享核装不下**
- e2-medium 共享核可分配 CPU 仅 ~940m，BoA Cloud SQL 版每后端多个 proxy sidecar → pod Pending。
- 解法：换 **e2-standard-2（独占核）× 3**。改机型前先做成本分析再定。

**9. populate job 的 proxy sidecar 跨容器杀不掉**
- BoA populate job 灌完数据后 `killall` 杀不掉**另一个容器**里的 proxy → job 永不 Complete（数据已灌，无害）。见 backlog B13（改 v2 原生 sidecar）。

### 销毁 / 成本

**10. PSA 拆除卡死（最常见的 destroy 坑）**
- 现象：GKE/SQL 都删了，卡在 `01-network` 的 `google_service_networking_connection`，报 `Producer services still using this connection`。
- 根因：Cloud SQL 删除后 GCP 后端释放 PSA 连接慢（20-30min+），期间 servicenetworking 标"in use"，无强制手段。
- 解法（已验证）：直接删底层 VPC peering 绕过 in-use 检查 → 删 PSA 地址 → 删 VPC。见 ROADMAP「已知坑 & Runbook」。

**11. destroy 空层/已删场景重跑报错（B14）**
- 现象：重跑 destroy ALL，02 的"关删除保护"预 apply 报 `network_self_link` 不存在。
- 根因：库/实例已删 + 上游 network state 已空，`-target=module.postgresql` 的 apply 却要重建，读不到已空的 network remote_state。
- 解法：先 gcloud 核实实际残留，别盲目重跑；根治见 backlog B14（预 apply 加"实例存在才跑"守卫 + 空层跳过）。

**12. 成本认知**
- 计费大头只有 **GKE 集群 + Cloud SQL 实例**（+ 少量 NAT/LB）；SA/WIF/state 桶/平台可观测性（告警/看板）**全免费**。
- Cloud SQL 实例名删除后**保留约 1 周**，勿在此期间复用同名。
- 用完即毁 = 按次几美元；SA/桶免费保留，`gcp-fintech-apply` 一键重建。

### 流水线 / 平台

**13. `workflow_dispatch` 必须在默认分支才出现 Run 按钮**
- 新手动 workflow 只在 develop → Actions UI 不显示；须先到 **main**（同名文件存在即可，再选分支跑）。平台/运维 workflow 常驻 main。

**14. Greenfield 冷启动守卫**
- 分层 remote_state 冷启动：上游未部署时下游 plan 会 fail。守卫：grep remote_state + 试读上游 output，读不到则 `skip=true` 跳过 apply。

**15. 平台可观测性独立管理**
- 平台层（监控/告警）自有 workflow/state/SA（`sa-fintech-platform`，仅 monitoring.editor），与业务 IaC(01-04) 生命周期分离。选型 Cloud Ops Suite（零运维/数据不出境/IaC 可管）。

### AIOps / LLM 载体

**16. Gemini 许可坑：席位 ≠ API**
- 现有 **Gemini Enterprise**（NotebookLM/Deep Research/传文档/GCS）是**给人用的席位**，不能驱动后端 agent（不能程序化调用、被告警触发、进自动循环）。
- 自建 AIOps agent 必须走 **Vertex AI Gemini API**（按 token；数据驻留+不训练+VPC-SC，fintech 合规）。
- 用法：Gemini Enterprise 做**人辅助**（RAG 问答、起草 RCA、用例 3/4 起步，$0 增量）；Vertex 留给自主闭环。见 [AIOPS-ROADMAP.md](AIOPS-ROADMAP.md)。

---

## 二、待补（各 Phase 跑完追加）

- [ ] Phase 2 压测/扩容：HPA 触发阈值、扩容耗时、P99、节点收敛行为
- [ ] Phase 2.5 可观测性数据面：L7 边缘信号、GMP 逐服务 RED、SLO 燃烧率
- [ ] Phase 3 混沌：爆炸半径隔离、核心账本零损、故障信号样本
- [ ] Phase 4 灾备：SQL failover RTO/RPO、zone drain 影响
- [ ] Phase 5 安全：Cloud Armor 拦截、ASM mTLS 服务间 403
