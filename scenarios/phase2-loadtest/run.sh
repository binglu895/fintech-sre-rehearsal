#!/usr/bin/env bash
# Phase 2 事件演练(Game Day):容量事故的完整生命周期
#   load → (分析) → remediate → (恢复) → stop
# 调用方式：ACTION=load|remediate|status|stop [REPLICAS=6] ./run.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${ACTION:-status}"
REPLICAS="${REPLICAS:-6}"

show_observe_hint() {
  echo ""
  echo "── 观测命令（另开终端）──"
  echo "  kubectl get hpa                # 有无 HPA / 副本数"
  echo "  kubectl get deploy             # 各服务当前副本"
  echo "  kubectl top pod                # 容器 CPU（饱和度）"
  echo "  kubectl get nodes              # 节点数（Cluster Autoscaler）"
  echo "  kubectl logs \$(kubectl get pod -l app=loadgenerator -o name | head -1) --tail=30"
  echo "                                 # Avg/Med/Max 延迟 + 失败率"
}

case "$ACTION" in
  load)
    echo "▶ [load] 制造事故：加压但【不部署 HPA】"
    echo "  各服务副本固定为 1，无法横向扩容 → CPU 打爆、延迟飙升。"
    # 确保没有残留 HPA（否则就不是"无处置"基线了）
    kubectl delete -f "$SCRIPT_DIR/hpa.yaml" --ignore-not-found >/dev/null 2>&1 || true
    kubectl scale deployment loadgenerator --replicas="$REPLICAS"
    echo ""
    echo "现在开始观测事故：等告警邮件 → 看板确认饱和 → 记录【处置前】P99/失败率。"
    show_observe_hint
    ;;

  remediate)
    echo "▶ [remediate] 处置：部署 HPA（CPU>60% 自动扩容）"
    kubectl apply -f "$SCRIPT_DIR/hpa.yaml"
    echo ""
    echo "HPA 就位，服务应开始横向扩容；节点不够时 Cluster Autoscaler 加节点（≤max）。"
    echo "观测恢复过程，记录【处置后】P99/失败率，与处置前对比。"
    show_observe_hint
    ;;

  status)
    echo "=== HPA（有=已处置 / 无=事故基线）==="
    kubectl get hpa 2>/dev/null || echo "(无 HPA，处于事故基线阶段)"
    echo ""
    echo "=== Deployments（副本数）==="
    kubectl get deploy
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes
    echo ""
    echo "=== Pod CPU（饱和度）==="
    kubectl top pod 2>/dev/null || echo "(metrics-server 数据未就绪)"
    echo ""
    echo "=== Loadgenerator 延迟 / 失败率 ==="
    kubectl logs "$(kubectl get pod -l app=loadgenerator -o name | head -1)" --tail=30 2>/dev/null \
      | grep -iE 'Aggregated|reqs|failures|Name' \
      || echo "(无日志或 loadgenerator 未运行)"
    ;;

  stop)
    echo "▶ [stop] 收尾：降载 + 删除 HPA"
    kubectl scale deployment loadgenerator --replicas=1
    kubectl delete -f "$SCRIPT_DIR/hpa.yaml" --ignore-not-found
    echo ""
    echo "HPA 缩副本约 5min，Cluster Autoscaler 缩节点约 10min。"
    ;;

  *)
    echo "未知 action: $ACTION。可选值：load | remediate | status | stop" >&2
    exit 1
    ;;
esac
