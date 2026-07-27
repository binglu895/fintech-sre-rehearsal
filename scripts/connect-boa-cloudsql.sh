#!/usr/bin/env bash
# =============================================================================
# connect-boa-cloudsql.sh — A3.3:把 Bank of Anthos 从内置 DB 切到我们的 Cloud SQL
#
# 做的事(幂等,可重跑):
#   ① 在 Cloud SQL 实例建 accounts-db / ledger-db 库 + admin 用户
#   ② 建 GSA(boa-gsa)+ 授 cloudsql.client / trace / monitoring
#   ③ 建 KSA(boa-ksa)+ 注解 + Workload Identity 绑定
#   ④ 建 cloud-sql-admin secret(连接名 + admin/admin,demo)
#   ⑤ 切换部署:删内置 DB 版 → 部署带 Cloud SQL Proxy sidecar 的版本 + 初始化 Job
#
# 用法:
#   ./scripts/connect-boa-cloudsql.sh            # 默认 dev
#   ENV=test ./scripts/connect-boa-cloudsql.sh   # 指定环境
#
# 前置:gcloud 已登录、有权限;GKE 集群已在跑(dev 底座已 apply)。
# =============================================================================
set -euo pipefail

# ── 参数 ──
PROJECT="${PROJECT:-kqeardr-gcp-shimano-internal}"
REGION="${REGION:-asia-northeast1}"
ENV="${ENV:-dev}"
BOA_REF="${BOA_REF:-v0.6.10}"
BOA_DIR="${BOA_DIR:-$HOME/bank-of-anthos}"
NS="${NS:-default}"
KSA=boa-ksa
GSA=boa-gsa

INSTANCE="ledger-db-$ENV"
CONN="$PROJECT:$REGION:$INSTANCE"
CLUSTER="fintech-$ENV-gke"
# dev/test 是 zonal,prod 是 regional
if [ "$ENV" = "prod" ]; then LOC_FLAG="--region=$REGION"; else LOC_FLAG="--zone=${REGION}-a"; fi

echo "▶ 环境=$ENV  实例=$INSTANCE  连接名=$CONN  集群=$CLUSTER"
echo

# 幂等辅助:忽略"已存在"类错误
ok() { "$@" || echo "  (跳过:资源可能已存在)"; }

# ── 取 GKE 凭证(kubectl 用)──
echo "== [0/5] 取 GKE 凭证 =="
gcloud container clusters get-credentials "$CLUSTER" $LOC_FLAG --project="$PROJECT"
echo

# ── ① Cloud SQL 库 + 用户 ──
echo "== [1/5] Cloud SQL 建库 + admin 用户 =="
ok gcloud sql databases create accounts-db --instance="$INSTANCE" --project="$PROJECT"
ok gcloud sql databases create ledger-db   --instance="$INSTANCE" --project="$PROJECT"
gcloud sql users create admin --instance="$INSTANCE" --password=admin --project="$PROJECT" \
  || gcloud sql users set-password admin --instance="$INSTANCE" --password=admin --project="$PROJECT"
echo

# ── ② GSA + 角色 ──
echo "== [2/5] 建 GSA + 授权 =="
ok gcloud iam service-accounts create "$GSA" --project="$PROJECT" --display-name="Bank of Anthos Cloud SQL"
for r in roles/cloudsql.client roles/cloudtrace.agent roles/monitoring.metricWriter; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:$GSA@$PROJECT.iam.gserviceaccount.com" --role="$r" --condition=None >/dev/null
done
echo "  ✓ boa-gsa 已授 cloudsql.client / trace / monitoring"
echo

# ── ③ KSA + 注解 + WI 绑定 ──
echo "== [3/5] KSA + Workload Identity 绑定 =="
ok kubectl create serviceaccount "$KSA" -n "$NS"
kubectl annotate serviceaccount "$KSA" -n "$NS" --overwrite \
  iam.gke.io/gcp-service-account="$GSA@$PROJECT.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding \
  "$GSA@$PROJECT.iam.gserviceaccount.com" --project="$PROJECT" \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:$PROJECT.svc.id.goog[$NS/$KSA]" >/dev/null
echo "  ✓ KSA=$KSA ↔ GSA=$GSA 绑定完成"
echo

# ── ④ 连接 secret(幂等)──
echo "== [4/5] cloud-sql-admin secret =="
kubectl create secret -n "$NS" generic cloud-sql-admin \
  --from-literal=username=admin --from-literal=password=admin \
  --from-literal=connectionName="$CONN" \
  --dry-run=client -o yaml | kubectl apply -f -
echo

# ── ⑤ 切换部署 ──
echo "== [5/5] 切换到 Cloud SQL 版部署 =="
if [ ! -d "$BOA_DIR" ]; then
  git clone --depth 1 --branch "$BOA_REF" https://github.com/GoogleCloudPlatform/bank-of-anthos.git "$BOA_DIR"
fi
cd "$BOA_DIR"

echo "  删除内置 DB 版(保留 jwt secret)..."
kubectl delete -f kubernetes-manifests --ignore-not-found -n "$NS"

echo "  部署 Cloud SQL 版(config + populate-jobs + 带 proxy 的服务)..."
kubectl apply -n "$NS" -f extras/cloudsql/kubernetes-manifests/config.yaml
kubectl apply -n "$NS" -f extras/cloudsql/populate-jobs
kubectl apply -n "$NS" -f extras/cloudsql/kubernetes-manifests
echo

# ── 输出 ──
echo "== 等待 frontend 外部 IP =="
IP=""
for i in $(seq 1 30); do
  IP=$(kubectl get svc frontend -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "$IP" ] && break
  sleep 10
done

cat <<EOF

=============================================================================
✅ A3.3 执行完成。核对:
  kubectl get pods                     # 后端应 2/2(service + cloud-sql-proxy sidecar)
  kubectl get jobs                     # populate-* 应 Complete
  gcloud sql databases list --instance=$INSTANCE --project=$PROJECT   # 应有 accounts-db / ledger-db

前端: http://${IP:-<还在分配,稍后 kubectl get svc frontend>}
登录: testuser / bankofanthos
=============================================================================
EOF
