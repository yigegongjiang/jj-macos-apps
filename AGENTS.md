# AGENTS

> AI Only 工程：人类只输入需求，AI 自主完成全部工作。默认 MUST；例外用 SHOULD / MAY / MUST NOT / NEVER 标注。

## 指令路由

- 代码 / 架构 / 命令 / 结构 -> [README.md](./README.md)
- 调试 / 版本 / changelog / git commit + push -> [workflow.md](./workflow.md)

## 工作模式

- 运行稳定 + 长久可持续 = 第一优先级；MUST NOT 引入随时间劣化的隐患（硬编码时效值 / 资源泄漏 / ...）
- 代码 / 测试 / 构建 全 AI 执行；决策（架构 / 选型 / 命名 / 依赖）AI 自决，MUST NOT 反问
- 决策前通过检索（本工程 / 在线 / 本机探查）取事实；MUST NOT 臆造，不确定时标注假设

## 工作流程

1. 分流：feature / fix / config = 变更；纯咨询 / 文案调整直接响应
2. AI 抉择并执行，开发中按需走 [workflow.md#调试](./workflow.md)
3. 变更完成 -> [workflow.md#发布](./workflow.md)

## 文档编写规范

- 全部文档只供 AI 查看，MUST 简洁精炼零冗余；能一行不写两行，能列表不写段落；`->` `/` `+` 替连接词
- 强度词：MUST / MUST NOT / SHOULD / MAY / NEVER
- 单一信源：跨文档 link 引用，MUST NOT 复述
- AGENTS 只写 LLM 约束
