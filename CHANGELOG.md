# Changelog

## v0.1.2

- 签名改为 identifier-only DR（不含 cdhash），FDA 完全磁盘访问授权跨重建长期有效，不再因重新打包失效。

## v0.1.1

- 移除 `L10n` 抽象，界面固定为英文；bundle 仅声明 `en`。

## v0.1.0

- 首个版本：macOS 应用管理器（Swift + AppKit 纯源码）。
- 扫描 `/Applications` + `/System/Applications` + `~/Applications`（及各自 Utilities）顶层 app，记录到 `~/.config/jj-apps/apps.json`。
- 从 `knowledgeC.db` `/app/usage` 取 `last_focus`（~19 天窗口），max-merge 持久化累积突破窗口。
- GUI：列表按 `last_focus` 降序 + 即时搜索 + 双击 / 回车启动 + 右键在访达显示 + ⌘R 刷新。
- FDA 未授权时降级（名称序 + 横幅一键跳转隐私设置 + 重新检测）。
- 界面英文。
