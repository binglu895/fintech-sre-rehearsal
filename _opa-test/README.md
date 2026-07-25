# OPA 策略本地自测

验证 `policies/gcp_sql.rego` 是否能「放行合规、拦截违规」。

## 方式 A:用真实 terraform plan(推荐)

```bash
cd 02-core-db
terraform init
terraform plan -out=plan.tfout
terraform show -json plan.tfout > plan.json
conftest test plan.json -p ../policies
# 合规配置应输出:no violations / PASS
```

把 02-core-db/main.tf 里的某个属性改成违规(如 availability_type = "ZONAL"),
重新 plan 后再 test,应看到对应 deny 报错。

## 方式 B:用现成的样本 plan.json(无需连 GCP)

本目录提供两份样本:
- `plan_compliant.json`  → conftest 应 PASS(0 violation)
- `plan_bad.json`        → conftest 应 FAIL(3 violations)

```bash
conftest test _opa-test/plan_compliant.json -p policies   # 期望 PASS
conftest test _opa-test/plan_bad.json       -p policies   # 期望 3 条 FAIL
```

安装 conftest:https://www.conftest.dev/install/
