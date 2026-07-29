# ── Dev 环境 · platform-observability(平台层可观测性)──
env                = "dev"
project_id         = "kqeardr-gcp-shimano-internal"
region             = "asia-northeast1"

# 告警通知邮箱(on-call)。演练用个人邮箱;生产改团队邮件组 / PagerDuty。
notification_email = "xinglu.a.chen@accenture.com"

# 阈值(可按演练需要微调)
cpu_saturation_threshold  = 0.8   # 容器 CPU 超 request 80% 触发(HPA 目标 60%)
node_saturation_threshold = 0.85  # 节点 CPU 超 allocatable 85% 触发
restart_threshold         = 2     # 5 分钟重启 > 2 次
