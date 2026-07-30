#!/usr/bin/env bash
# Phase 2 压测场景：HPA + loadgenerator 加压
# 调用方式：ACTION=start|stop|status [REPLICAS=6] ./run.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${ACTION:-status}"
REPLICAS="${REPLICAS:-6}"

case "$ACTION" in
  start)
    echo "▶ [start] 部署 HPA + 加压 (loadgenerator × $REPLICAS)"
    kubectl apply -f "$SCRIPT_DIR/hpa.yaml"
    kubectl scale deployment loadgenerator --replicas="$REPLICAS"
    echo ""
    echo "观测命令（三终端）："
    echo "  kubectl get hpa -w"
    echo "  kubectl get nodes -w"
    echo "  kubectl logs -l app=loadgenerator --tail=40 -f | grep -iE 'Aggregated|reqs|failures'"
    ;;

  stop)
    echo "▶ [stop] 降载 + 删除 HPA"
    kubectl scale deployment loadgenerator --replicas=1
    kubectl delete -f "$SCRIPT_DIR/hpa.yaml" --ignore-not-found
    echo ""
    echo "HPA 缩副本约 5min，Cluster Autoscaler 缩节点约 10min"
    ;;

  status)
    echo "=== HPA ==="
    kubectl get hpa 2>/dev/null || echo "(无 HPA，场景未启动)"
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes
    echo ""
    echo "=== Pod CPU ==="
    kubectl top pod 2>/dev/null || echo "(metrics-server 数据未就绪)"
    echo ""
    echo "=== Loadgenerator 最新日志 ==="
    kubectl logs -l app=loadgenerator --tail=30 2>/dev/null \
      | grep -iE 'Aggregated|reqs|failures|Name' \
      || echo "(无日志或 loadgenerator 未运行)"
    ;;

  *)
    echo "未知 action: $ACTION。可选值：start | stop | status" >&2
    exit 1
    ;;
esac
