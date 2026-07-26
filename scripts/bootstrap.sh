#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — 三环境 CI/CD 的 GCP 前置资源一键创建(幂等)
#
# 创建:3 个 state 桶 + 3 个 Service Account(+基础角色) + 1 个 WIF Pool/Provider
#       + 把每个 SA 按分支绑定给 GitHub 仓库。
# 结束后打印需要填入 GitHub Repository Variables 的 6 个值。
#
# 幂等:可重复执行,已存在的资源会跳过(不会报错中断)。
#
# 用法:
#   PROJECT=kqeardr-gcp-shimano-internal REPO=binglu895/fintech-sre-rehearsal ./scripts/bootstrap.sh
#
# 前置:已安装并登录 gcloud(gcloud auth login),且有项目 IAM 管理权限。
# =============================================================================
set -euo pipefail

# ── 参数(可用环境变量覆盖)──
PROJECT="${PROJECT:-kqeardr-gcp-shimano-internal}"

# REPO 未显式设置时,尝试从 git remote 自动探测(git@github.com:org/repo.git 或 https)
REPO="${REPO:-}"
if [ -z "$REPO" ]; then
  ORIGIN="$(git config --get remote.origin.url 2>/dev/null || true)"
  # 先去掉结尾的 .git,再取 <org>/<repo>
  REPO="$(printf '%s' "$ORIGIN" | sed -E 's#\.git$##' | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#')"
fi
if [ -z "$REPO" ]; then
  echo "✗ 未能确定 REPO。请显式指定,例如:" >&2
  echo "    REPO=binglu895/fintech-sre-rehearsal ./scripts/bootstrap.sh" >&2
  exit 1
fi

REGION="${REGION:-asia-northeast1}"
POOL_ID="${POOL_ID:-github-pool}"
PROVIDER_ID="${PROVIDER_ID:-github-provider}"

ENVS=(dev test prod)

echo "▶ 项目: $PROJECT"
echo "▶ 仓库: $REPO"
echo "▶ region: $REGION"
echo

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"

# 幂等辅助:命令失败(多为"已存在")时打印提示但不中断
try() { "$@" || echo "  (跳过:资源可能已存在)"; }

# ── 0. 启用必要 API ──
echo "== [0/5] 启用 API =="
gcloud services enable \
  compute.googleapis.com container.googleapis.com \
  sqladmin.googleapis.com servicenetworking.googleapis.com \
  iamcredentials.googleapis.com sts.googleapis.com \
  --project="$PROJECT"
echo

# ── 1. 三个 state 桶(开版本控制)──
echo "== [1/5] 创建 state 桶 =="
for e in "${ENVS[@]}"; do
  BUCKET="fintech-iac-states-$e"
  if gcloud storage buckets describe "gs://$BUCKET" --project="$PROJECT" >/dev/null 2>&1; then
    echo "  gs://$BUCKET 已存在"
  else
    gcloud storage buckets create "gs://$BUCKET" \
      --project="$PROJECT" --location="$REGION" --uniform-bucket-level-access
  fi
  gcloud storage buckets update "gs://$BUCKET" --versioning --project="$PROJECT" >/dev/null
  echo "  ✓ gs://$BUCKET (versioning on)"
done
echo

# ── 2. 三个 Service Account ──
echo "== [2/5] 创建 Service Account =="
for e in "${ENVS[@]}"; do
  SA="sa-fintech-$e"
  SA_EMAIL="$SA@$PROJECT.iam.gserviceaccount.com"
  if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" >/dev/null 2>&1; then
    echo "  $SA_EMAIL 已存在"
  else
    gcloud iam service-accounts create "$SA" \
      --project="$PROJECT" --display-name="fintech IaC $e"
    echo "  ✓ $SA_EMAIL"
  fi
done
echo

# ── 3. 给 SA 授基础角色(演练用;生产请按最小权限收敛)──
echo "== [3/5] 授予 SA 角色 =="
ROLES=(
  roles/compute.networkAdmin
  roles/compute.securityAdmin
  roles/cloudsql.admin
  roles/container.admin
  roles/servicenetworking.networksAdmin
  roles/storage.admin
  roles/iam.serviceAccountUser
)
for e in "${ENVS[@]}"; do
  SA_EMAIL="sa-fintech-$e@$PROJECT.iam.gserviceaccount.com"
  for role in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding "$PROJECT" \
      --member="serviceAccount:$SA_EMAIL" --role="$role" \
      --condition=None >/dev/null
  done
  echo "  ✓ $SA_EMAIL 已授 ${#ROLES[@]} 个角色"
done
echo

# ── 4. Workload Identity Federation(Pool + Provider)──
echo "== [4/5] 配置 WIF =="
if gcloud iam workload-identity-pools describe "$POOL_ID" \
     --project="$PROJECT" --location=global >/dev/null 2>&1; then
  echo "  Pool $POOL_ID 已存在"
else
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$PROJECT" --location=global --display-name="GitHub Actions"
  echo "  ✓ Pool $POOL_ID"
fi

if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
     --project="$PROJECT" --location=global \
     --workload-identity-pool="$POOL_ID" >/dev/null 2>&1; then
  echo "  Provider $PROVIDER_ID 已存在"
else
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project="$PROJECT" --location=global \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
    --attribute-condition="assertion.repository=='$REPO'"
  echo "  ✓ Provider $PROVIDER_ID (仅信任仓库 $REPO)"
fi

POOL_RES="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID"
PROVIDER_RES="$POOL_RES/providers/$PROVIDER_ID"
echo

# ── 5. 把每个 SA 绑定给 GitHub ──
echo "== [5/5] 绑定 SA ← GitHub =="
# dev 只在 push develop 部署 → 仅信任 develop 分支(最严)。
# test/prod 需在 PR→main 阶段跑 plan(此时 OIDC ref=refs/pull/N/merge,非 main),
#   故绑定到仓库级 principalSet,让 PR 也能拿身份跑 plan。
#   apply 仍被三重门挡住:apply job 仅 push 触发 + caller 限 main + prod 需 Environment 审批。
bind_ref() {  # $1=env  $2=ref(如 refs/heads/develop)
  local e="$1" ref="$2"
  local SA_EMAIL="sa-fintech-$e@$PROJECT.iam.gserviceaccount.com"
  gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --project="$PROJECT" --role=roles/iam.workloadIdentityUser \
    --member="principalSet://iam.googleapis.com/$POOL_RES/attribute.ref/$ref" \
    >/dev/null
  echo "  ✓ sa-fintech-$e ← $ref"
}
bind_repo() {  # $1=env  —— 仓库级信任(覆盖 PR 事件)
  local e="$1"
  local SA_EMAIL="sa-fintech-$e@$PROJECT.iam.gserviceaccount.com"
  gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --project="$PROJECT" --role=roles/iam.workloadIdentityUser \
    --member="principalSet://iam.googleapis.com/$POOL_RES/attribute.repository/$REPO" \
    >/dev/null
  echo "  ✓ sa-fintech-$e ← repo:$REPO (含 PR)"
}
bind_ref  dev  refs/heads/develop
bind_repo test
bind_repo prod
echo

# ── 输出:填入 GitHub Repository Variables 的值 ──
cat <<EOF
=============================================================================
✅ GCP 前置资源就绪。请在 GitHub 设置以下 Repository Variables:
   (Settings → Secrets and variables → Actions → Variables)
-----------------------------------------------------------------------------
  WIF_PROVIDER_DEV   = $PROVIDER_RES
  WIF_PROVIDER_TEST  = $PROVIDER_RES
  WIF_PROVIDER_PROD  = $PROVIDER_RES

  GCP_SA_EMAIL_DEV   = sa-fintech-dev@$PROJECT.iam.gserviceaccount.com
  GCP_SA_EMAIL_TEST  = sa-fintech-test@$PROJECT.iam.gserviceaccount.com
  GCP_SA_EMAIL_PROD  = sa-fintech-prod@$PROJECT.iam.gserviceaccount.com
-----------------------------------------------------------------------------
接着创建 3 个 Environment(dev / test / production-apply)并配审批,
详见 docs/SETUP-3ENV.md 第三节。
=============================================================================
EOF
