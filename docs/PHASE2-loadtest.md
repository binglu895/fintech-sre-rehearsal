# Phase 2:流量激增与扩容 — 压测 Runbook

> 目标:20x 流量下不宕机、P99<500ms、扩容<2min。
> 环境:dev(BoA + Cloud SQL 已在跑)。压测用 BoA 自带的 loadgenerator(Locust),不需外部工具。

## 成本护栏（开跑前确认）

- GKE `max_count` 已封顶（`envs/dev/03-gke-platform.tfvars`）——autoscaler 不会暴涨。
- **时间盒**:压测跑完立刻降回或 destroy,别过夜。
- autoscaler 只按需加节点,用不到不花钱。

---

## 一、准备（原地生效,不重建,不动 BoA）

**① GKE 开弹性伸缩**(改了 tfvars: min=3 max=4)
```
gcp-fintech-apply → env=dev, layer=03-gke-platform (Branch=develop)
```
原地更新节点池 autoscaling,约 2-4 分钟。

**② 给 BoA 服务加 HPA**
```bash
kubectl apply -f k8s/phase2-hpa.yaml
kubectl get hpa      # 看到 6 个 HPA,TARGETS 显示当前 CPU%
```

---

## 二、基线快照（压测前记录）

```bash
kubectl get hpa                  # 各服务副本数(基线应为 1)
kubectl get pods | wc -l         # pod 总数
kubectl get nodes                # 节点数(基线 3)
kubectl logs -l app=loadgenerator --tail=20   # Locust 当前延迟统计(p50/p95/p99)
```

---

## 三、加压（阶梯提升负载）

BoA 的 loadgenerator 是 Locust,**扩它的副本数 = 成倍加流量**:
```bash
kubectl scale deployment loadgenerator --replicas=3    # 3x 流量
# 观察几分钟后再往上加:
kubectl scale deployment loadgenerator --replicas=6    # 6x
kubectl scale deployment loadgenerator --replicas=10   # ~10x+
```

---

## 四、观察扩容（开几个终端 watch）

```bash
kubectl get hpa -w        # HPA:CPU% 上升 → REPLICAS 自动增加
kubectl get pods -w       # 新 Pod 被创建
kubectl get nodes -w      # 节点不够时 autoscaler 扩到 max(4)
```

**关注链路**:
```
负载↑ → 服务 CPU↑ → HPA 扩 Pod → 节点 CPU 满 → cluster autoscaler 扩节点(≤max)
```

---

## 五、测指标

**延迟(P99)**——看 Locust 统计:
```bash
kubectl logs -l app=loadgenerator --tail=30 | grep -iE 'p99|percentile|Aggregated'
```
Locust 周期性打印聚合响应时间(含 95%/99%)。或用 GCP **Cloud Monitoring → GKE 仪表盘**看延迟/CPU 曲线。

**扩容生效时间(Time-to-Scale)**——从"HPA 触发"到"新 Pod Ready"/"新节点 Ready"的时长,目标 <2min。

**是否宕机**——加压期间前端 `http://<frontend-ip>` 持续可访问、转账不失败。

---

## 六、验收标准

| 指标 | 目标 |
|---|---|
| P99 延迟 | <500ms |
| 扩容生效 | <2min |
| 可用性 | 加压全程不宕机、转账不失败 |
| 爆炸控制 | 节点不超过 max_count(护栏生效)|

---

## 七、收尾（降负载 + 缩容 + 控成本）

```bash
# 1. 负载降回基线
kubectl scale deployment loadgenerator --replicas=1

# 2. HPA 会自动缩 Pod;autoscaler ~10min 后缩节点
kubectl get hpa -w

# 3.(可选)删 HPA,GKE 降回固定 3 节点
kubectl delete -f k8s/phase2-hpa.yaml
#    改 envs/dev/03-gke-platform.tfvars min=max=3 → re-apply(原地)

# 4. 若今天到此为止,destroy 止血:
#    gcp-fintech-destroy → env=dev, layer=ALL, DESTROY
```

---

## 观察记录模板（填完即 Phase 2 成果）

| 负载(loadgen 副本) | HPA 峰值副本 | 节点数 | P99 延迟 | 扩容耗时 | 宕机? |
|---|---|---|---|---|---|
| 1(基线) | 1 | 3 | | - | 否 |
| 3 | | | | | |
| 6 | | | | | |
| 10 | | | | | |
