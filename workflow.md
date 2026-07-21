```When Editing
本文档 = 调试 + 发布流程; MUST NOT 塞工程说明 (→ README.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 编写规范
```

# 环境

- `gh` 已登录（可 push）
- Swift 6.2+ / Xcode 26+（`defaultIsolation` 需要）

# 调试

- Debug 快编：`swift build` -> `./.build/debug/jj-apps`
- Release 装机：`./package.sh` -> `open -a /Applications/jj-apps.app`
- 验证：
  - 秒开：先 JSON 缓存渲染，再后台 scan 补差
  - FDA denied：仍列全部 app，`last_focus` 无历史 = `0`，显示授权横幅
  - FDA granted：`last_focus` = knowledgeC 值，按其降序
- FDA 授权稳定性：签名 DR 钉 identifier-only（不含 cdhash），重建长期有效。首次从旧 ad-hoc 切换需重授一次：设置 -> 完全磁盘访问 -> 删旧条目 -> 重新添加 `/Applications/jj-apps.app` -> 退出重开

# 发布

代码变更完成后执行。交付闸 = `package.sh` 成功（编译失败即中止）。

## 步骤

1. 写版本：改根 `VERSION`（`package.sh` 注入 `Info.plist`）+ 同步 `CHANGELOG.md`。递增规则：PATCH 默认 / MINOR 新功能 / MAJOR 不兼容
2. 打包 + 提交：

```bash
./package.sh
git add -A
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin master
git push origin vX.Y.Z
```

> 未签名 / 未公证 -> 分发给他人时对方首次运行需 `xattr -dr com.apple.quarantine <path>`。本机构建无 quarantine，直接可用。
