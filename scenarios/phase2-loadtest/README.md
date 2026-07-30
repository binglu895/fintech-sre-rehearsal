# 场景：Phase 2 压测 / HPA + Cluster Autoscaler

## 目标
验证告警驱动的自动扩容闭环：加压 → CPU 饱和告警 → HPA 扩 Pod → Cluster Autoscaler 扩节点 → 降载收缩。

## 前置条件
- `gcp-fintech-apply`（env, layer=ALL）已完成
- `gcp-fintech-app`（env, deploy）已完成，Bank of Anthos 运行正常
- `platform-observability`（env, apply）已完成，告警/看板就绪

## 参数
| 参数 | 说明 | 默认值 |
|---|---|---|
| `env` | 目标环境 | dev |
| `replicas` | loadgenerator 副本数（越大压力越高） | 6 |

## HPA 规则
所有关键服务 CPU 均值 > 60% 触发扩容，max 副本数：

| 服务 | maxReplicas |
|---|---|
| frontend | 5 |
| balancereader | 5 |
| transactionhistory | 5 |
| ledgerwriter | 5 |
| userservice | 4 |
| contacts | 4 |

节点上限：dev 4 节点（`max_count`），test/prod 按 tfvars。

## 运行（事件演练 / Game Day）

不是一键扩容，而是走完一条容量事故的完整生命周期，量化"处置前 vs 处置后"。

Actions → `gcp-fintech-scenario` → scenario=`phase2-loadtest`

| 步骤 | action | 做什么 | 你要做的 |
|---|---|---|---|
| 1 事故 | `load`（replicas=6） | 加压，**不装 HPA**（副本固定=1） | 等告警邮件 → 看板确认饱和 → 记录【处置前】P99/失败率 |
| 2 分析 | `status` | 查看当前状态 | 判断瓶颈：这是容量问题吗？ |
| 3 处置 | `remediate` | 部署 HPA（CPU>60% 扩容） | 观察恢复 → 记录【处置后】P99/失败率 |
| 4 恢复 | `status` | 确认延迟/失败率回落 | 对比处置前后 |
| 5 收尾 | `stop` | 降载 + 删 HPA | — |

> 关键：`load` 阶段故意不装 HPA，让你亲眼看到"无自愈能力"时系统烂成什么样，
> 再用 `remediate` 处置对比。这才是能写进复盘报告的对照数据。

## 复盘记录

> 每次运行后填写，保留历史对比（O1 前 / O1 后）。

### 基准（无 O1 L7 信号）· 处置前后对照

| 日期 | 阶段 | loadgen 副本 | 告警触发? | 峰值副本 | 节点 | Avg/Med/Max(ms) | 失败率 | 宕机? | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 2026-07-30 | 旧版(HPA+加压同时) | 6 | 收到邮件 | fe:5/5 us:4/4 | 3 | 2800/2300/19000 | 0.3–0.8% | 否 | 改版前的混合数据，仅参考 |
| | 处置前(load,无HPA) | 6 | | 全 1 | | | | | 事故基线：无自愈 |
| | 处置后(remediate,有HPA) | 6 | | | | | | | 扩容后恢复 |

### O1 后对比（补充 L7 边缘信号后）

| 日期 | loadgen 副本 | 告警触发? | HPA 峰值副本 | 节点峰值 | P99(服务端) | 扩容耗时 | 宕机? | 备注 |
|---|---|---|---|---|---|---|---|---|
| | 1（基线） | 否 | 1 | 3 | — | — | 否 | |
| | 6 | | | | | | | |
