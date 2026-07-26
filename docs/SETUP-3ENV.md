# 三环境 CI/CD 落地手册(dev / test / prod)

本手册列出改造后需要**你在 GCP 和 GitHub 侧手动创建**的资源与配置。
当前三环境共用同一个 GCP 项目 `kqeardr-gcp-shimano-internal`,靠命名前缀 + CIDR 分段 +
独立 state 桶 + 独立 Service Account 模拟隔离。未来拆多项目时,只需改 `envs/<env>/*.tfvars`
里的 `project_id`,代码零改动。

---

## 一、环境总览

| 维度 | dev | test | prod |
|------|-----|------|------|
| GCP 项目 | kqeardr-gcp-shimano-internal(共用) | 同 | 同 |
| 触发分支 | `develop`(push 自动) | `main`(push 自动) | `main`(test 后,人工审批) |
| 资源命名前缀 | `fintech-dev-*` | `fintech-test-*` | `fintech-prod-*` |
| CIDR 段 | 10.0.0.0 ~ 10.15 | 10.16 ~ 10.31 | 10.32 ~ 10.47 |
| 控制平面 /28 | 172.16.0.0/28 | 172.16.0.16/28 | 172.16.0.32/28 |
| State 桶 | fintech-iac-states-dev | fintech-iac-states-test | fintech-iac-states-prod |
| Service Account | sa-fintech-dev@… | sa-fintech-test@… | sa-fintech-prod@… |
| GitHub Environment | `dev` | `test` | `production-apply` |
| OPA 合规级别 | 宽松(ZONAL/无删除保护可豁免) | 严格(同 prod) | 严格 |
| SQL 规格 | ZONAL / db-custom-1-3840 | REGIONAL / db-custom-2-8192 | REGIONAL / db-custom-2-8192 |

---

## 二、GCP 侧要创建的资源(需要你执行)

以下 gcloud 命令为参考模板,请按实际项目/组织调整。**请你自行执行**(涉及 IAM 授权)。

### 1. 三个 State 桶

```bash
PROJECT=kqeardr-gcp-shimano-internal
for e in dev test prod; do
  gcloud storage buckets create gs://fintech-iac-states-$e \
    --project=$PROJECT --location=asia-northeast1 \
    --uniform-bucket-level-access
  gcloud storage buckets update gs://fintech-iac-states-$e --versioning
done
```

### 2. 三个 Service Account(最小权限,按环境隔离)

```bash
for e in dev test prod; do
  gcloud iam service-accounts create sa-fintech-$e \
    --project=$PROJECT --display-name="fintech IaC $e"
done
```

给每个 SA 授予其部署所需角色(示例,请按最小权限收敛):

```bash
# 示例:prod SA 授予 compute/sql/container/networking 相关角色
SA_PROD=sa-fintech-prod@$PROJECT.iam.gserviceaccount.com
for role in roles/compute.networkAdmin roles/cloudsql.admin \
            roles/container.admin roles/servicenetworking.networksAdmin \
            roles/storage.admin roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA_PROD" --role="$role"
done
# dev / test 同理(dev 可更宽松以便演练)
```

### 3. Workload Identity Federation(可复用一个 Pool)

```bash
# 一个 Pool + 一个 Provider 即可(三环境共用),差异体现在绑定的 SA 上
gcloud iam workload-identity-pools create github-pool \
  --project=$PROJECT --location=global --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc github-provider \
  --project=$PROJECT --location=global \
  --workload-identity-pool=github-pool \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository=='<你的-org>/<你的-repo>'"
```

### 4. 把每个 SA 绑定给 GitHub(按分支/环境收窄,增强隔离)

```bash
POOL=projects/$(gcloud projects describe $PROJECT --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool
REPO=<你的-org>/<你的-repo>

# dev SA:只信任 develop 分支
gcloud iam service-accounts add-iam-policy-binding \
  sa-fintech-dev@$PROJECT.iam.gserviceaccount.com --project=$PROJECT \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/$POOL/attribute.ref/refs/heads/develop"

# test / prod SA:只信任 main 分支(prod 的最终门禁靠 GitHub Environment 审批)
for e in test prod; do
  gcloud iam service-accounts add-iam-policy-binding \
    sa-fintech-$e@$PROJECT.iam.gserviceaccount.com --project=$PROJECT \
    --role=roles/iam.workloadIdentityUser \
    --member="principalSet://iam.googleapis.com/$POOL/attribute.ref/refs/heads/main"
done
```

> WIF Provider 完整资源名形如:
> `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/providers/github-provider`

---

## 三、GitHub 侧要配置的(需要你操作)

### 1. Repository Variables(Settings → Secrets and variables → Actions → Variables)

三环境共用一个 Provider 时,`WIF_PROVIDER_*` 三个值可相同;`GCP_SA_EMAIL_*` 必须区分。

| 变量名 | 值 |
|--------|-----|
| `WIF_PROVIDER_DEV` | projects/…/providers/github-provider |
| `WIF_PROVIDER_TEST` | (同上或独立 provider) |
| `WIF_PROVIDER_PROD` | (同上或独立 provider) |
| `GCP_SA_EMAIL_DEV` | sa-fintech-dev@PROJECT.iam.gserviceaccount.com |
| `GCP_SA_EMAIL_TEST` | sa-fintech-test@PROJECT.iam.gserviceaccount.com |
| `GCP_SA_EMAIL_PROD` | sa-fintech-prod@PROJECT.iam.gserviceaccount.com |

> 旧的 `WIF_PROVIDER` / `GCP_SA_EMAIL`(仓库级)已不再被引用,可删除。

### 2. Environments(Settings → Environments)

| Environment | 保护规则 | 说明 |
|-------------|---------|------|
| `dev` | 无 | 自动部署,不阻断 |
| `test` | Required reviewers = 1 人(可选) | 轻量审批 |
| `production-apply` | Required reviewers = SRE 团队(≥1);Wait timer = 5 分钟;Deployment branches = 仅 `main` | Prod 硬门禁 |

### 3. Branch Protection(Settings → Branches)

- `main`:
  - Require a pull request before merging(至少 1 review)
  - Require status checks to pass:勾选 plan 相关的 check(如 `test_network / plan`)
  - 禁止直接 push
- `develop`:保护可宽松(允许开发者快速迭代 Dev)

---

## 四、部署流程回顾

```
push develop ──────────────▶ 部署 Dev(自动,OPA 宽松)

PR → main ─────────────────▶ 对 Test + Prod 两套配置跑 plan/OPA(只验证)
  merge 到 main
      │
      ▼
push main ─┬─▶ 部署 Test(自动,轻量审批,OPA 严格)
           │      │ 全部层成功
           │      ▼
           └─▶ 部署 Prod(SRE 审批 + Wait timer,OPA 严格,层间串行)
```

---

## 五、首次部署顺序(重要)

各环境内部必须按层顺序首次部署(因层间 remote_state 依赖):

```
01-network → 02-core-db → 03-gke-platform → 04-apps
```

流水线已用 `needs` 强制此顺序。首次可只改动 `01-network/` 触发,逐层推进;
或一次性改动全部层,流水线会自动按序执行。

---

## 六、销毁(演练环境清理)

Actions → `gcp-fintech-destroy` → Run workflow:
1. 选择 `env`(dev/test/prod)
2. 选择 `layer`(**逆序**:04-apps → 03-gke → 02-db → 01-network)
3. 输入确认词 `DESTROY`

prod 环境的销毁同样走 `production-apply` 审批门。
