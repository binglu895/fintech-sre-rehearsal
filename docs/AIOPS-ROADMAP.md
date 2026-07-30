# AIOps Roadmap（独立管理 · 后续推进）

> **状态：PARKED（待命）**。当前主线是把 fintech SRE 场景跑完 + 补全架构（见 [ROADMAP.md](ROADMAP.md)）。
> AIOps 逐步推进，管理上独立成本文档；**不硬 fork**——AIOps 长在 SRE 平台之上（复用其遥测/应用/流水线），
> 将来代码落地时做**独立模块**（同 repo、独立生命周期，同 `platform-observability` 思路）。

---

## ★ 北极星：fintech AIOps（终极目的）

**用一个逼真的 fintech 栈（Bank of Anthos + 三环境 CI/CD + 真实攻防/负载场景），在合规护栏内把「可观测性数据面 → LLM 推理 → 门控自动化」这条 AIOps 闭环一段段跑通。**

关键认知：**可观测性（指标/日志/追踪）不是终点，是 AIOps 的数据面**——没有干净信号 + 事件流，AI 无从分析。这个平台 = 安全训练/验证 AIOps agent 的沙箱（不能让 AI 直接在生产上"发现问题、自动发布、自动封 IP"，得先在逼真环境跑通闭环）。

### 分层参考架构（自下而上）
```
⑤ 治理护栏（横切）：人在环审批 · 审计可追溯 · OPA 策略即代码 · 最小权限 · 可解释
④ 闭环行动（门控）：渐进发布 canary/shadow · GitOps 修复PR · Cloud Armor 规则 · 告警/工单
③ 推理决策：LLM agent + RAG(runbook/拓扑/历史) → 根因 · 方案 · 风险/成本评估
② 检测：异常检测 · 信号关联 · SLO 燃烧率
① 遥测数据面：指标 GMP · 日志 Cloud Logging · 追踪 OTel · 事件/审计 · 安全流日志
```

### 目标用例 → 架构映射
| 用例 | ①数据 | ②检测 | ③推理 | ④行动（门控）|
|---|---|---|---|---|
| 日志发现问题→方案→影子发布 | 日志+trace+部署 diff | 错误率异常/新签名 | 根因→修复方案 | Argo Rollouts canary/shadow → SLO 校验 → 自动回滚 |
| 异常流量→定位攻击→防御→告警 | Flow Logs+Armor 日志 | 流量模式异常 | 分类攻击+定源 | 生成 Cloud Armor 规则(IaC PR) + 告 SOC |
| 客户请求→可行性/风险/成本→日程 | 请求+架构/账单数据 | 意图解析 | 估可行/风险/成本 | 方案+日程草案 → 审批 |
| 用户 issue→分析→应对策略 | issue+历史工单/KB | 分类/去重/定级 | 定级+责任人+应对 | 建工单+建议回复 → 确认 |

### fintech 红线（不可妥协）
1. **人在环 + 门控**：碰钱/客户/生产的行动，AI 只提议，人/策略批准。
2. **审计可追溯 + 可解释**：每个决策留痕、可复现、能向监管解释。
3. **策略即代码护栏（OPA）** 框死 agent 能做什么（同现在卡业务部署 SA 的思路）。
4. agent 用**独立最小权限 SA**（同平台 SA / 部署 SA 分离思路）。
5. **数据驻留**：喂 LLM 的遥测不出境 → Vertex AI / 项目内（同监控选型）。

### 每个 SRE Phase 喂给哪个 AIOps 用例
| Phase（见 ROADMAP.md）| 产出信号 | AIOps 用例 |
|---|---|---|
| 2 压测/HPA | 性能指标/饱和度/扩缩事件 | 容量/性能异常 → 扩容建议 |
| 3 混沌 | 故障→错误日志/trace | **日志发现问题→方案→影子发布（首个 PoC）** |
| 4 DR/HA | 故障切换事件 | 韧性决策 |
| 5 零信任/Armor | 攻击流量/WAF 日志 | **异常流量→防御策略** |
| 6 Backstage | 请求/issue 工单流 | **请求/issue→可行性/应对** |

### 接入顺序
1. 先凑齐**三支柱数据面**（ROADMAP 的 O 系列 + Phase 2.5）——没有干净信号，AIOps 无从谈起。
2. **Phase 3 混沌**时做首个 AIOps PoC：LLM 读"注入故障后的错误日志+trace" → 输出根因假设 + rollback/canary 建议，**只生成建议不自动执行**，人工核对准确率。
3. 准确率够 → 接 **Argo Rollouts** 做「建议→影子发布→SLO 校验→自动回滚」首个闭环（全程门控）。

---

## vs 前沿主流（定位，判断截至 2026 初）

AIOps 正从**传统 ML-AIOps**（事件关联/异常检测/拓扑 RCA，如 Dynatrace Davis/Datadog Watchdog/Moogsoft）过渡到
**Agentic AIOps / "AI SRE"**（LLM agent 调查循环 + OTel + eBPF 零码 + 因果 AI + 持续 profiling + 变更智能，如 Datadog Bits AI/Grafana Sift/Cleric/Traversal/Causely）。

- **我们领先/对齐**：治理·人在环·审计·OPA·数据驻留（fintech 级，领先多数商业方案）；渐进自治（suggestion-first）；**PR-as-action**（GitOps 承载 AI 行动，可审计可逆）；SLO 门控闭环。
- **我们落后/过简**：① 推理层"一次性读日志"→ 应为 **agentic 调查循环**（工具+迭代+证据引用）；② 缺 **变更智能**（头号 RCA 加速器）；③ 缺 **因果/拓扑 grounding**（压幻觉）；④ 数据面缺 **eBPF 零码 + profiling**；⑤ 无 **eval/反馈**；⑥ 未控 **token/成本**（关联降噪+tail-sampling）；⑦ 漏 **提示注入**（日志=攻击者可注入=不可信输入，fintech 安全面）；⑧ 未用**现成 ML**（Adaptive Protection/SQL Insights/Monitoring anomaly）。

→ 补 ①–④ 从"上一代+LLM 点缀"跨到"真 agentic AI SRE"；⑤–⑧ 让它可度量·可控成本·可审计（差异化）。

---

## AI 系列 Backlog（AIOps 硬化 · 工作量 S/M/L + 成本量级）

- **AI1【P1·L】推理层：一次性 → agentic 调查循环**：ReAct + 工具集（查指标/拉日志/取 trace/diff 部署/只读 kubectl）+ 迭代 + **每结论附证据**。与前沿最大代差。成本主驱动 = LLM 推理。
- **AI2【P1·S】变更智能（一等信号）**：CI/CD 部署/配置事件 → Pub/Sub→BigQuery + "what changed" 工具。**现成流水线，ROI 最高，近零基建成本。**
- **AI3【P2·M】因果/拓扑 grounding**：从 Cloud Trace/eBPF 建服务依赖图约束 LLM，压 RCA 幻觉。
- **AI4【P2·M】eBPF 零码 + 持续 profiling**：Beyla/Grafana Alloy（轻）或 Pixie（有节点开销）拿 RED+网络+安全信号 + **Cloud Profiler（免费）**。少改 BoA。
- **AI5【P1·M】Eval harness + 反馈回流**：Phase 3 混沌当"labeled incident 工厂"→ 量 RCA 准确率/MTTR；人工反馈改 RAG/few-shot。
- **AI6【P2·M】关联降噪 + tail-sampling**：OTel Collector tail-sampling → 先成 incident 再 RCA；**净省钱**（降摄入 + 省 token）。
- **AI7【P1·S】提示注入防护**：遥测=不可信输入（结构化摘要、日志内容不得变指令、证据隔离与来源标注）。fintech 安全红线，纯工程无基建成本。
- **AI8【P3·M】预测/预防 + 善用现成 ML**：Monitoring anomaly / BQML 预测 SLO 燃烧 → 预扩容；Cloud SQL Insights（免费）；Cloud Armor Adaptive Protection（Enterprise 贵，演练用**标准规则**替代）。

---

## LLM 载体：两条腿走（省钱 + 合规）

```
人辅助层（现有 Gemini Enterprise 席位，$0 增量）   ← 先跑，验证"LLM 对我们数据做 RCA 行不行"
        │  验证准确率够了
        ▼
自主闭环层（Vertex AI 按量）                        ← 真自动化时才花 LLM 钱
```

### 关键许可澄清（踩过的坑）
| 产品 | 是什么 | 能驱动后端 agent 吗 |
|---|---|---|
| **Gemini Enterprise**（现有，Agentspace 血统：NotebookLM/Deep Research/传文档/GCS 集成）| 给**人用**的知识工作台，按席位 | ❌ 席位≠API，交互式，不能被告警程序触发、进不了自动循环 |
| **Gemini for Workspace / Code Assist** | 人用助手/编码助手，按席位 | ❌ 非后端推理 |
| **Vertex AI · Gemini API** | **程序化 API**（按 token / 预置吞吐）| ✅ 自建 agent 从代码调；数据驻留(asia-northeast1)+不训练+VPC-SC，fintech 合规 |

**现有 Gemini Enterprise 怎么用（不浪费、$0 增量）**：
- NotebookLM 灌 runbook/postmortem/架构 → grounded 问答（**人用版 RAG**）。
- 混沌/事件后把日志/trace 导 GCS → 人 chat/总结/**起草 RCA**（AI1 手动前身、AI5 素材源）。
- 用例 3/4（客户请求可行性、issue 分类应对）先用它**人辅助起步**。
- 注意：喂的遥测若含敏感数据先核实合规；Deep Research 会外联 → 内部分析用文档/GCS grounding。

**待自动化时切 Vertex（AI1）**：核实 Vertex 用量能否并入现有 **GCP 承诺用量/企业折扣（CUD/EDP）**，可能落进已有支出。

---

## 补齐差距的工作 + 成本预估

> asia-northeast1、2026 初、量级估算；真实值等 O0 部署后可实测。现有基线（跑起来时）约 $10-13/天。

| AI 项 | 工作内容 | 基建成本 | LLM 成本 | 工作量 |
|---|---|---|---|---|
| AI1 agentic 推理 | ReAct 循环 + 工具集 + 证据引用；跑 Cloud Run(缩零) | ~$0 | **主驱动**：每次调查 100k–1M token；Flash ~$0.05-0.5 / Pro·Claude ~$0.5-5 | **L**(~1-2 周) |
| AI2 变更智能 | 部署事件→Pub/Sub→BigQuery + "what changed" | ~$0-2/mo | — | **S**(~1 天) |
| AI3 因果/拓扑 | Cloud Trace 建服务图约束 LLM | ~$0(复用 trace) | 略增上下文 | **M**(~3 天) |
| AI4 eBPF+profiling | Beyla(轻)/Pixie(重) + Cloud Profiler(免费) | Beyla ~$0 / Pixie **+~1 节点(~$52/mo)** + GMP ~$5-15/mo | — | **M**(~3-4 天) |
| AI5 Eval+反馈 | 混沌造 labeled 集；批量打分；反馈回流 | ~$0(BQ 分文级) | 每轮 ~$1-10 | **M**(~3 天) |
| AI6 降噪+tail-sampling | OTel Collector 尾采样；告警去重成 incident | **净省钱** | **省 token** | **M**(~3 天) |
| AI7 提示注入防护 | 遥测当不可信输入；结构化摘要；来源隔离 | $0 | 略降 | **S**(~1-2 天) |
| AI8 预测+现成 ML | BQML 预测 SLO 燃烧；SQL Insights；Armor 标准 | BQML 分文-单$ + Armor 标准 ~$10-20/mo | — | **M**(~3 天) |

### 汇总
| | 估算 |
|---|---|
| **按次演练增量**（几小时，destroy 后）| **~$5-25/次**（几乎全是 LLM，看模型选型）|
| **若 24/7 月增量** | **~$50-180/mo**（LLM $20-100 + eBPF[Beyla ~$10 / Pixie +$52] + GMP/BQ ~$10 + Armor 标准 ~$15），减 tail-sampling 省的摄入 |
| **主驱动** | **LLM 推理**（可控：模型选型 + 批处理 + 尾采样缩上下文）|
| **免费红利** | Cloud Profiler、Cloud SQL Insights、GKE Dataplane V2 eBPF |
| **反而省钱** | AI6 尾采样/去重 |
| **贵→跳过** | Cloud Armor Adaptive Protection（Enterprise ~$3,000/mo）→ 演练用标准规则 |

**总工作量**（solo 兼职）：S×3 + M×5 + L×1 ≈ **约 4-6 周**，可增量做；AI2/AI7（S）性价比最高先上。

### 控成本建议
1. **Gemini Flash 打底**，难 case 才升 Pro/Claude。
2. **喂结构化摘要不喂原始日志**（AI6+AI7 一箭双雕：省 token + 防注入）。
3. **Beyla 优先于 Pixie**（避开 +1 节点）。
4. **用完即毁** → 按次几美元，不进月费。
5. **先白嫖免费 ML**（Profiler / SQL Insights / Monitoring anomaly）再自研。

---

## 推进前提（都在 SRE 主线完成后）
- 三支柱数据面就绪（ROADMAP 的 O0–O5 + Phase 2.5）。
- 至少跑过 Phase 3 混沌（产出 labeled incident 素材）。
- 确认 Vertex AI 计费口径（是否并入 GCP 承诺用量）。
