#!/usr/bin/env bash
# =============================================================================
# connect-boa-cloudsql.sh — 部署 Bank of Anthos(Cloud SQL 版)到指定环境的 GKE
#
# 【应用侧】(本脚本):取凭证 / 建 KSA + 注解 / 建 cloud-sql-admin secret / 部署 BoA
# 【基础设施侧】已 codify 进 terraform,是本脚本的前置(先 apply 好):
#   - 02-core-db :accounts-db / ledger-db 库 + admin 用户
#   - 04-apps    :boa-gsa-<env> + IAM(cloudsql.client 等) + Workload Identity 绑定
#   → 先 gcp-fintech-apply(env=<env>, layer=ALL),再跑本脚本
#
# 用法:
#   ./scripts/connect-boa-cloudsql.sh            # 默认 dev
#   ENV=test ./scripts/connect-boa-cloudsql.sh
# =============================================================================
set -euo pipefail

PROJECT="${PROJECT:-kqeardr-gcp-shimano-internal}"
REGION="${REGION:-asia-northeast1}"
ENV="${ENV:-dev}"
BOA_REF="${BOA_REF:-v0.6.10}"
BOA_DIR="${BOA_DIR:-$HOME/bank-of-anthos}"
NS="${NS:-default}"
KSA=boa-ksa
GSA="boa-gsa-$ENV"          # 与 04-apps terraform 一致(单项目按 env 区分)

INSTANCE="ledger-db-$ENV"
CONN="$PROJECT:$REGION:$INSTANCE"
CLUSTER="fintech-$ENV-gke"
# dev/test 是 zonal,prod 是 regional
if [ "$ENV" = "prod" ]; then LOC_FLAG="--region=$REGION"; else LOC_FLAG="--zone=${REGION}-a"; fi

echo "▶ 环境=$ENV  实例=$INSTANCE  GSA=$GSA  集群=$CLUSTER"
echo "  (前置:02/04 层 terraform 已 apply → 库/用户/GSA/IAM/WI 就绪)"
echo

ok() { "$@" || echo "  (跳过:资源可能已存在)"; }

# ── [1/4] 取 GKE 凭证 ──
echo "== [1/4] 取 GKE 凭证 =="
gcloud container clusters get-credentials "$CLUSTER" $LOC_FLAG --project="$PROJECT"
echo

# ── [2/4] KSA + 注解(GSA/WI 绑定由 terraform 04-apps 管)──
echo "== [2/4] KSA + 注解 =="
ok kubectl create serviceaccount "$KSA" -n "$NS"
kubectl annotate serviceaccount "$KSA" -n "$NS" --overwrite \
  iam.gke.io/gcp-service-account="$GSA@$PROJECT.iam.gserviceaccount.com"
echo

# ── [3/4] cloud-sql-admin secret(库/用户由 terraform 02 管;这里给 proxy 连接名 + 凭证)──
echo "== [3/4] cloud-sql-admin secret =="
kubectl create secret -n "$NS" generic cloud-sql-admin \
  --from-literal=username=admin --from-literal=password="${BOA_DB_PASSWORD:-admin}" \
  --from-literal=connectionName="$CONN" \
  --dry-run=client -o yaml | kubectl apply -f -
echo

# ── [4/4] 部署 BoA(Cloud SQL 版)──
echo "== [4/4] 部署 Bank of Anthos(Cloud SQL 版) =="
if [ ! -d "$BOA_DIR" ]; then
  git clone --depth 1 --branch "$BOA_REF" https://github.com/GoogleCloudPlatform/bank-of-anthos.git "$BOA_DIR"
fi
cd "$BOA_DIR"
kubectl delete -f kubernetes-manifests --ignore-not-found -n "$NS"   # 删内置 DB 版(若存在)
kubectl apply -n "$NS" -f extras/cloudsql/kubernetes-manifests/config.yaml
kubectl apply -n "$NS" -f extras/cloudsql/populate-jobs
kubectl apply -n "$NS" -f extras/cloudsql/kubernetes-manifests
echo

# ── 输出 ──
IP=""
for i in $(seq 1 30); do
  IP=$(kubectl get svc frontend -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "$IP" ] && break
  sleep 10
done

cat <<EOF

=============================================================================
✅ 应用侧部署完成。核对:
  kubectl get pods                     # 后端 2/2(service + cloud-sql-proxy)
  kubectl get jobs                     # populate-* 数据已灌(proxy 不退出会卡 Running,无害)
前端: http://${IP:-<还在分配,稍后 kubectl get svc frontend>}
登录: testuser / bankofanthos
=============================================================================
EOF
