package lib

import rego.v1

# ── 公共工具:供各服务策略复用,避免重复代码 ──

# 从 plan 中筛出指定类型、且本次会创建或更新的资源。
# 只看 create/update,忽略 delete/no-op(删除的资源无需再校验合规)。
resources_of_type(plan, resource_type) := [r |
	some r in plan.resource_changes
	r.type == resource_type
	actions := r.change.actions
	some a in actions
	a in {"create", "update"}
]

# 安全取嵌套字段,路径不存在时返回 default(避免 plan 结构缺字段导致报错)
get_default(obj, key, default) := value if {
	value := obj[key]
} else := default
