# Changelog

## v0.1.8

- App 图标葡萄放大一些（各层 SVG 外包 `<g transform>`：以果串中心放大 1.12 并居中），四周留白更少。

## v0.1.7

- App 图标换成葡萄：`Resources/AppIcon.icon`（Icon Composer 分层 SVG + Dark 背景）替换 `AppIcon.icns`；`install-local.sh` 用 `actool` 编译出 `Assets.car` + `AppIcon.icns`，`Info.plist` 增 `CFBundleIconName`。

## v0.1.6

- `package.sh` -> `scripts/install-local.sh`：脚本自 `cd` 工程根（任意目录可执行）、路径改相对、新增 `INSTALL_DIR` 覆盖、安装后 `codesign --verify` 校验。行为不变。
- 文档同步：`README.md` / `workflow.md` / `Package.swift` 注释。

## v0.1.5

- 时间相对显示：<1h 改为 `Xm`（四舍五入到分），1h~72h 沿用 `Xh`，超过仍走 JST 绝对时间。

## v0.1.4

- 全量重命名 `jj-apps` -> `jj-macos-apps`：product / bundle-id / 二进制 / `/Applications/*.app` / 数据目录 `~/.config/jj-macos-apps` / UserDefaults / UI 文案。
- 首启自动迁移：`~/.config/jj-apps` -> `~/.config/jj-macos-apps`；`JJApps.windowW/H` -> `JJMacOSApps.windowW/H`；`package.sh` 顺带清理老 `/Applications/jj-apps.app` 与进程。
- 需手动一次：系统设置 -> 完全磁盘访问 删旧条目 + 新 bundle-id 重授权。

## v0.1.3

- 全量 md 与源码注释精简：删冗余 WHAT，保留非显而易见的 WHY。无行为变更。

## v0.1.2

- 签名改 identifier-only DR（不含 cdhash），FDA 授权跨重建长期有效。

## v0.1.1

- 移除 `L10n` 抽象；界面固定英文，bundle 仅声明 `en`。

## v0.1.0

- 首版：macOS 应用管理器（Swift + AppKit 纯源码）。
- 扫 `/Applications` + `/System/Applications` + `~/Applications`（含各自 Utilities）顶层 app -> `~/.config/jj-macos-apps/apps.json`。
- 从 `knowledgeC.db` `/app/usage` 取 `last_focus`（~19 天窗口），max-merge 累积突破。
- GUI：列表按 `last_focus` 降序 + 即时搜索 + 双击 / Enter 启动 + 右键 Reveal + ⌘R 刷新。
- FDA 未授权降级：名称序 + 横幅一键跳设置。
- 界面英文。
