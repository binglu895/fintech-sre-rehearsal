#!/usr/bin/env bash
# =============================================================================
# create-issues.sh — 一键把后续课题清单建成 GitHub Issues(含标签/优先级/依赖)
#
# 前置:
#   1. 安装 GitHub CLI:  winget install --id GitHub.cli   (或 https://cli.github.com)
#   2. 登录:            gh auth login
#   3. 在仓库目录运行:   ./scripts/create-issues.sh
#
# 幂等:标签已存在会跳过;issue 会重复创建,请勿重复运行(或先删旧的)。
# =============================================================================
set -euo pipefail

REPO="${REPO:-}"
if [ -z "$REPO" ]; then
  ORIGIN="$(git config --get remote.origin.url 2>/dev/null || true)"
  REPO="$(printf '%s' "$ORIGIN" | sed -E 's#\.git$##' | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#')"
fi
[ -n "$REPO" ] || { echo "✗ 未能确定 REPO,请 REPO=<org>/<repo> ./scripts/create-issues.sh" >&2; exit 1; }
echo "▶ 目标仓库: $REPO"

# ── 标签(已存在则跳过)──
mklabel() { gh label create "$1" --repo "$REPO" --color "$2" --description "$3" 2>/dev/null && echo "  + label $1" || true; }
echo "== 创建标签 =="
mklabel "P0"           "b60205" "最高优先级"
mklabel "P1"           "d93f0b" "高优先级"
mklabel "P2"           "fbca04" "中优先级"
mklabel "P3"           "0e8a16" "低优先级"
mklabel "phase-1"      "1d76db" "Phase 1 收尾"
mklabel "enhancement"  "a2eeef" "工程完善/增强"
mklabel "prerequisite" "5319e7" "后续阶段前置"
mklabel "phase-2"      "c5def5" "流量激增与扩容"
mklabel "phase-3"      "c5def5" "混沌工程"
mklabel "phase-4"      "c5def5" "灾备高可用"
mklabel "phase-5"      "c5def5" "零信任抗DDoS"
mklabel "phase-6"      "c5def5" "开发者平台"
mklabel "done"         "0e8a16" "已完成(记录用)"

# ── 创建 issue 的辅助函数 ──
mk() {  # $1=title  $2=labels(逗号分隔)  $3=body
  gh issue create --repo "$REPO" --title "$1" --label "$2" --body "$3" >/dev/null
  echo "  ✓ $1"
}

# 已完成项:创建后立即关闭,作为审计记录(closed issue 带完成说明)
mkdone() {  # $1=title  $2=labels  $3=body
  local url
  url=$(gh issue create --repo "$REPO" --title "$1" --label "$2,done" --body "$3")
  gh issue close "$url" --repo "$REPO" --comment "✅ 已完成并验证,归档为记录。" >/dev/null 2>&1 || true
  echo "  ✓ (done) $1"
}

echo "== A. Phase 1 收尾 =="
mkdone "[P0] 部署 test 环境并验证 REGIONAL HA + 晋升链" "phase-1,P0" \
"**目标**:部署 test 环境,关闭 Phase 1 Step 5 的 REGIONAL HA 验收,并验证 develop→PR→main→test 晋升链。

**验收(已完成)**:
- [x] test 全部层(network→db→gke→apps)按序部署成功
- [x] 晋升链验证:test 自动部署 → test_complete 门 → prod 卡 production-apply 审批(不批,零成本)
- [x] REGIONAL HA **配置**验收(availabilityType=REGIONAL + 跨区 secondaryZone)
- [x] 无公网 IP、GKE 挂内网子网

**说明**:HA 的 failover **行为**测试(RPO=0/RTO<60s)属 Phase 4——需应用+流量才测得出对程序的影响。"

mkdone "[P0] 合并 develop → main 成为正式基线" "phase-1,P0" \
"**目标**:把验证过的三环境代码从 develop 合并到 main,作为正式基线。

**已完成**:
- [x] main 含完整三环境代码 + 全部 workflow(合并 PR)
- [x] push main 触发晋升链(test 部署、prod 卡审批)
- [x] 过时 PR #5 已关闭、分支已清理(见 A6)"

mk "[P0][前置] Bank of Anthos 应用层落地到 GKE (04-apps)" "phase-1,P0,prerequisite" \
"**目标**:把 Bank of Anthos 微服务真正部署到 GKE(填充目前空壳的 04-apps 层)。
这是 **Phase 2~6 全部演练的总前置**——没有真实运行的应用,压测/混沌/灾备/DDoS 都无从谈起。

**范围**:
- [ ] 04-apps 层用 kubernetes/helm 部署 Bank of Anthos
- [ ] 应用连到 02-core-db 的 Cloud SQL(替换内置 DB)
- [ ] 前端可访问,转账/账本流程跑通

**依赖**:GKE(03)已就绪;配合 B9(Secret Manager 取库凭证)"

mk "[P1] main 分支保护补 Required status checks" "phase-1,P1" \
"**目标**:main 分支保护除 review 外,把流水线 plan checks 设为必过。
**验收**:
- [ ] test_network/plan 等 checks 设为 Required
- [ ] OPA deny 违规的 PR 无法合并"

mk "[P2] CMEK 状态桶加密" "phase-1,P2" \
"**目标**:3 个 state 桶启用客户托管密钥(CMEK)加密,满足金融合规。
**步骤**:建 KMS keyring+key → 授权 GCS 服务代理 encrypt/decrypt → 设桶默认 KMS key。
**状态**:暂缓(用户决定)。"

mkdone "[P2] 清理过时 PR #5 与分支卫生" "phase-1,P2" \
"**目标**:关闭已过时的 PR #5(feature/multi-env-cicd),清理无用分支。
**已完成**:删除 feature/multi-env-cicd(自动关闭 PR #5)、删除已合并的 chore/manual-workflows-to-main,远程只剩 main + develop。"

echo "== B. 流水线 / IaC 工程完善 =="
mkdone "[已完成] Greenfield 守卫:上游未部署则跳过下游 plan" "enhancement" \
"**成果**:_layer.yml 加 greenfield 守卫。消费上游 remote_state 的层(02/03)在上游 network
尚未部署(无输出)时,把 plan 从 fail 转为 skip(green + notice),优雅处理分层冷启动。
- 探测:init 01-network backend + terraform output network_self_link
- skip=true → 跳过 init/plan/OPA/checkov/上传,apply job 也跳过
- push 场景上游先 apply(needs 保证)→ 不跳过,正常部署;稳态 PR 正常验证
提交:6849709"

mkdone "[已完成] Terraform provider 缓存提速" "enhancement" \
"**成果**:三个 workflow(_layer plan+apply、apply、destroy)用 actions/cache 缓存
TF_PLUGIN_CACHE_DIR,省掉每次 init 重新下载 provider。key 按 provider.tf 哈希失效。
GKE/SQL 云侧创建时间省不了,但每层 init 快 30-60s。提交:501331d"

mkdone "[已完成] apply/destroy 支持 ALL 一键批量" "enhancement" \
"**成果**:手动 apply(正序 01→02→03→04)、destroy(逆序 04→03→02→01)均加 ALL 选项,
一次运行批量处理全部层。destroy ALL 在循环内自动先关 02 的 deletion_protection。提交:2781f8d"

mk "[P3] workflow_dispatch 输入需同步 main 才在 UI 生效" "enhancement,P3" \
"**问题**:apply/destroy 的 env/layer 等输入选项,Run workflow 表单认默认分支(main)。
改在 develop 上不会立即在 UI 出现,需合并到 main。
**选项**:① 约定'workflow 输入改动及时同步 main';② 研究 Terraform Stacks/Terragrunt 迁移,
顺带消除分层 remote_state 的 greenfield 尖角。参见 docs/ROADMAP.md。"

mk "[P2] destroy 的 PSA 拆除健壮化" "enhancement,P2" \
"**问题**:Cloud SQL 删除后 PSA(servicenetworking connection)释放慢(20-30min+),
destroy 01-network 报 'Producer services still using this connection',无强制删除手段。
**已验证手动解法**:直接删底层 compute VPC peering(绕过 in-use 检查)+ 全局地址 + VPC。
详见 docs/ROADMAP.md 第六节 Runbook。
**改进方向**:① destroy 失败时自动 fallback 到 gcloud compute peering 强删;
② 或把 servicenetworking connection 移出 terraform(out-of-band 管理);③ 或加带耐心的重试。"

mk "[P1] PR 自动评论 terraform plan 结果" "enhancement,P1" \
"**目标**:在 PR 页面自动评论各层 terraform plan 摘要(要创建/变更什么),方便审批与审计。
金融合规常见做法。可用 actions/github-script 或 terraform show 输出贴评论。"

mk "[P1] Checkov 结果上传 GitHub Security (SARIF)" "enhancement,P1" \
"**目标**:Checkov 扫描结果以 SARIF 格式上传到 GitHub Security 面板。
需要 permissions: security-events: write。"

mk "[P1] GKE 专用节点 SA(最小权限)" "enhancement,P1" \
"**目标**:GKE 节点当前复用部署 SA(权限过大)。改为每环境建专用节点 SA,
仅授 logging/monitoring/artifactregistry 等节点必需角色。"

mk "[P2] CI 加 terraform fmt / validate / tflint" "enhancement,P2" \
"**目标**:PR 阶段加静态检查(fmt/validate/tflint),提交前拦低级错误。"

mk "[P2] 部署通知(Slack/钉钉)" "enhancement,P2" \
"**目标**:部署成功/失败推送到 Slack 或钉钉,携带环境名+状态。"

mk "[P2] 预置更多 org policy 合规" "enhancement,P2" \
"**目标**:提前规避企业 org policy 拦截(如 Shielded VM、OS Login、外部 IP 限制),
像之前 VPC Flow Logs 那样在代码里预置合规配置。"

mk "[P2] GCP 预算告警 / 成本护栏" "enhancement,P2" \
"**目标**:配置 GCP 预算告警,演练防超支。可加自动销毁定时任务。"

mk "[P3] staging 环境扩展 demo" "enhancement,P3" \
"**目标**:复制 envs/dev → envs/staging + 建对应桶/SA/Environment,
验证'复制 envs 目录即扩环境'的可扩展性宣称。"

mk "[P1] 应用连 Cloud SQL:Secret Manager + Workload Identity" "enhancement,P1" \
"**目标**:Bank of Anthos 通过 Secret Manager + GKE Workload Identity 安全获取数据库凭证,
不落明文。为 A3 的配套。"

echo "== C. Phase 2-6 SRE 演练路线 =="
mk "[Phase 2] 流量激增与扩容" "phase-2,prerequisite" \
"**场景**:银行大促/秒杀,流量暴增 20 倍。
**动作**:JMeter 压测 GKE → 观察 HPA(Pod 扩容)+ 节点自动扩容 + Cloud SQL 只读副本。
**指标**:P99<500ms、扩容生效<2min、不宕机。
**依赖**:A3(应用已上 GKE)。"

mk "[Phase 3] 混沌工程与爆炸半径" "phase-3,prerequisite" \
"**场景**:微服务崩溃/误改配置/误删 state。
**动作**:Chaos Mesh 搞挂非核心微服务(contacts/users)、模拟 state 误操作。
**指标**:爆炸半径隔离,核心转账(ledger-writer)与账本库零受损。
**依赖**:A3。"

mk "[Phase 4] 灾备与高可用(HA)" "phase-4,prerequisite" \
"**场景**:单可用区完全瘫痪。
**动作**:强制 Cloud SQL Failover、隔离整个 GKE Zone。
**指标**:RPO=0、RTO<60s、应用重试自动恢复。
**依赖**:A3 + A1(REGIONAL 环境)。"

mk "[Phase 5] 零信任与抗 DDoS" "phase-5,prerequisite" \
"**场景**:黑客攻击/SQL 注入/DDoS。
**动作**:Cloud Armor WAF/DDoS 拦截、Anthos Service Mesh mTLS 零信任。
**指标**:恶意 IP 秒级熔断、未授权服务间访问 403。
**依赖**:A3。"

mk "[Phase 6] 开发者平台与新产品上线" "phase-6,prerequisite" \
"**场景**:新微服务(个人理财)一键入驻。
**动作**:自建 Backstage IDP,网页填表自动触发 CI/CD 注入 GKE。
**指标**:零命令行、零合规漏洞、核心业务 0 停机。
**依赖**:A3 + 成熟的 CI/CD。"

echo
echo "✅ 全部 issue 创建完成。查看:https://github.com/$REPO/issues"
