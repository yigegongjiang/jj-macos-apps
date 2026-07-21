# AGENTS

> 当前 project 是 AI Only 工程，人类输入的所有需求，都需要 AI(Claude Code、Codex...) 自主完成后续的所有工作。
> 默认 MUST(必须强制遵守); 仅例外用 SHOULD/MAY/MUST NOT/NEVER 标注。

## 指令路由（MUST）

- 【MUST】代码 / 架构 / 命令 / 结构 → [README.md](./README.md)
- 【MUST】调试 / 版本 / changelog / git commit+push → [workflow.md](./workflow.md)

## 工作模式 (MUST、AI-only)

- 【MUST】运行稳定 + 长久可持续 = 第一优先级；MUST NOT 引入随时间劣化的隐患（硬编码时效值 / 资源泄漏 / ...）
- 【MUST】代码 / 测试 / 构建 全部由 AI 执行，人类输入需求或咨询，AI 自主完成后续工作
- 【MUST】决策（架构 / 选型 / 命名 / 依赖）AI 自行抉择，MUST NOT 拉人类进设计回路，MUST NOT 反问
- 【MUST】决策前通过检索（本工程 / 在线 / 本机探查）获取事实，据事实做最优决策
- 【MUST NOT】臆造事实 / 输出 / 结果 / 来源；不确定时标注假设

## 工作流程

1. **分流**：判断输入是否涉及行为或交付物变更（feature / fix / config = 需求变更）；纯咨询 / 纯文案调整 → 直接响应，跳过后续
2. AI 抉择并执行；开发中按需走 [workflow.md#调试](./workflow.md) 验证变更
3. 变更完成执行 [workflow.md#发布](./workflow.md)

## 文档编写规范

- 全部文档只供 AI 查看，MUST 简洁精炼，零冗余；MUST NOT 废话填充
- 能一行不写两行，能列表不写段落；短句；`->` `/` `+` 替连接词
- 强度词：MUST / MUST NOT / SHOULD / MAY / NEVER
- 单一信源：跨文档用 link 引用，MUST NOT 复述事实
- AGENTS 只写 LLM 约束，MUST NOT 塞工程说明 / 命令 / 安装
