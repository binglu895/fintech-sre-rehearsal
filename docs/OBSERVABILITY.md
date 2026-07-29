# 平台层可观测性(platform-observability)

平台团队独立管理的可观测性层:告警(发现机制)+ 黄金信号看板。**与业务 IaC(01–04)分离**——自有 workflow、自有 state、自有 SA。

## 选型

**Cloud Operations Suite(GCP 原生托管)+ 后续 GMP/OTel**。

| 标准 | 结论 |
|---|---|
| 合规/数据驻留 | 数据留在自己 GCP 项目内,不出境(vs Datadog 类 SaaS)|
| 运维负担 | 零运维,不用养 Prometheus/Thanos(控成本)|
| 集成 | GKE/Cloud SQL 指标自动流入;Cloud Trace 已埋(BoA 插桩 + GSA `cloudtrace.agent`)|
| IaC | `google_monitoring_*` 全可 Terraform |
| 反锁定 | 演进加 GMP(PromQL 兼容)+ OTel 埋点(换后端不重埋)|

fintech 常见:大行自建 Prometheus/Grafana + Splunk/ELK + Jaeger,OTel 统一埋点;云上 fintech 用托管方案(GMP / Cloud Ops)。

## SLO 目标(演练契约)

| SLI | 目标 | 说明 |
|---|---|---|
| 可用性 | 99.9% | 前端成功响应比例 |
| 延迟 P99 | < 500ms | 交易请求 |
| 扩容生效 | < 2min | 告警→新副本/节点 Ready |

> 可用性/延迟属**应用级**信号,当前 L4 LoadBalancer 拿不到,靠 Locust 客户端侧观测。生产用 GMP + L7 Ingress 服务端采集(见下)。

## 本层产出

- **通知渠道**:邮件 on-call(`notification_email`)。
- **告警策略**(黄金信号里当前能采到的):
  - 容器 CPU 饱和(request utilization > 0.8,2min)— Saturation
  - 节点 CPU 饱和(allocatable utilization > 0.85,3min)— 容量/自动扩容
  - 容器重启(5min > 2 次)— Errors(crashloop)
- **看板**:黄金信号(容器 CPU/内存、节点 CPU、容器重启)。

### 黄金信号缺口(backlog)
Latency / Traffic / Errors(应用级)需:**GMP** 抓 BoA Prometheus 指标 + **OpenTelemetry** 埋点 + **L7 Ingress + Cloud Armor**(Phase 5)。届时看板补齐 4 信号,告警加 P99/错误率 SLO 燃烧率。

## 部署(独立于业务流水线)

```bash
# 1) 前置资源:创建平台 SA(sa-fintech-platform,仅 monitoring.editor)+ 开 Monitoring API
PROJECT=kqeardr-gcp-shimano-internal REPO=binglu895/fintech-sre-rehearsal ./scripts/bootstrap.sh

# 2) 在 GitHub → Settings → Variables 增加两个仓库变量(值见 bootstrap 输出):
#    WIF_PROVIDER_PLATFORM   (= 与其它 WIF_PROVIDER_* 同值)
#    GCP_SA_EMAIL_PLATFORM   = sa-fintech-platform@<project>.iam.gserviceaccount.com

# 3) 跑 workflow(Actions → platform-observability → Run workflow):
#    env=dev, action=apply
```

删除:同 workflow,`action=destroy`,`confirm=DESTROY`。

## 告警驱动的压测演练(重现真实事件)

```
①加压制造高峰 → ②Saturation 告警触发(邮件)→ ③看黄金信号看板确认饱和
→ ④HPA 依 CPU>60% 横向扩容(节点不够 Cluster Autoscaler 加节点,≤max)
→ ⑤看板确认恢复(CPU 回落、P99 回落)→ ⑥降载缩容回退 → ⑦复盘填表
```

```bash
# 前置:业务环境已就绪 + HPA 就位
kubectl apply -f k8s/phase2-hpa.yaml

# ①制造高峰
kubectl scale deployment loadgenerator --replicas=6

# ②③盯:告警邮件 + 看板 + 三终端
kubectl get hpa -w        # CPU% 冲过 60% → REPLICAS 自动涨
kubectl top pod           # 症状:容器 CPU 逼近 request/limit
kubectl get nodes -w      # 节点 3 → 4(Cluster Autoscaler)
kubectl logs -l app=loadgenerator --tail=40 | grep -iE 'Name|Aggregated|reqs'  # P99 / failures

# ⑥高峰过去缩容回退
kubectl scale deployment loadgenerator --replicas=1
# HPA ~5min 缩副本(stabilizationWindow),Cluster Autoscaler ~10min 缩节点
```

### 复盘记录模板

| 负载(loadgen 副本) | 告警是否触发 | HPA 峰值副本 | 节点数 | P99 | 扩容耗时 | 宕机? |
|---|---|---|---|---|---|---|
| 1(基线) | 否 | 1 | 3 | | - | 否 |
| 6 | | | | | | |
| 10 | | | | | | |
