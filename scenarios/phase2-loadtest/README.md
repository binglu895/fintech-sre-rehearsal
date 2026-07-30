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

## 运行
Actions → `gcp-fintech-scenario` → scenario=`phase2-loadtest`

1. `action=start`（replicas=6）：部署 HPA + 加压
2. 等待：告警邮件触发 → 看板确认饱和 → HPA/节点扩容
3. `action=status`：随时查看当前状态
4. `action=stop`：降载 + 清理 HPA

## 复盘记录

> 每次运行后填写，保留历史对比（O1 前 / O1 后）。

### 基准（无 O1 L7 信号）

| 日期 | loadgen 副本 | 告警触发? | HPA 峰值副本 | 节点峰值 | P99(客户端侧) | 扩容耗时 | 宕机? | 备注 |
|---|---|---|---|---|---|---|---|---|
| | 1（基线） | 否 | 1 | 3 | — | — | 否 | |
| | 6 | | | | | | | |
| | 10（可选） | | | | | | | |

### O1 后对比（补充 L7 边缘信号后）

| 日期 | loadgen 副本 | 告警触发? | HPA 峰值副本 | 节点峰值 | P99(服务端) | 扩容耗时 | 宕机? | 备注 |
|---|---|---|---|---|---|---|---|---|
| | 1（基线） | 否 | 1 | 3 | — | — | 否 | |
| | 6 | | | | | | | |
