```When Editing
本文档作用: 工程工作流程 (调试 / 发布); MUST NOT 写工程说明 (→ README.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范; 发布内按顺序编号; 高危操作用 `>` 引用块标禁用条件
```

# 可用工具

- `gh` — 已登录（git push）
- Swift 6.2+ / Xcode 26+（`defaultIsolation` 需要）

# 调试

- 快速编译（Debug）：`swift build` → 运行 `./.build/debug/jj-apps`
- 构建 + 装到 /Applications（Release + ad-hoc 签名，无参数）：`./package.sh` → `open -a /Applications/jj-apps.app`
- 验证要点：
  - **秒开**：启动先读 `~/.config/jj-apps/apps.json` 渲染（首帧即有内容），后台 scan 再补新装 / 删卸载。
  - **FDA denied**：仍列出全部 app；`last_focus` 无历史值时为 `0`；显示授权横幅。
  - **FDA granted**：`last_focus` = KnowledgeC `/app/usage` 最近区间结束时间；按其降序。

# 发布

代码变更完成后执行。交付闸 = `./package.sh` 打包成功（编译失败即中止）。

## TL;DR

1. 写版本：改根 `VERSION` 一处（`package.sh` 注入 `Info.plist`）+ 同步 `CHANGELOG.md`
2. 本机发布 + 提交：`./package.sh` → commit + annotated tag + push branch + tag

## 1. 写版本

- 默认递增 PATCH；新功能 → MINOR；不兼容改动 → MAJOR。
- 单一版本源：编辑根 `VERSION`；同步 `CHANGELOG.md`（与 tag 一致）。

## 2. 本机发布 + 提交

```bash
./package.sh                         # 打包 → ad-hoc 签名 → 装 /Applications（编译失败则中止）
git add -A
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin master
git push origin vX.Y.Z
```

> 未签名 / 未公证 → 分发给他人时对方首次运行需 `xattr -dr com.apple.quarantine <path>`。本机构建产物无 quarantine，直接可用。
