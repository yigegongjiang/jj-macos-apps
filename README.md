```When Editing
本文档作用: 工程总览 (价值主张 / 使用 / 架构 / 结构); MUST NOT 写发布流程 (→ workflow.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范; 章节按需增删, 只留项目真有的; 首行一行价值主张
```

# jj-macos-apps

macOS 应用管理器：扫描主机 app，按最近一次处于前台的时间排序 + 即时搜索，双击启动。纯 Swift + AppKit，单一 JSON 数据文件，零第三方依赖。

## 使用

- 构建 + 装到 /Applications：`./package.sh`（无参数；见 [workflow.md#调试](./workflow.md)）。
- 打开即**秒开**：先读 JSON 缓存直接渲染，随后后台扫描补新装 / 删卸载的 app。
- 搜索框即时过滤（名称 / bundleId / 路径，多词 AND）；列表 3 列（App / Last Used / Last Update），点击日期列头切换排序键，再点同列 toggle 升 / 降序（默认 `last_focus` 降序）；双击 / 回车启动，右键「Reveal in Finder」/「Add to Ignore」，⌘R 刷新，⌘F 聚焦搜索。
- **Ignore**：右键「Add to Ignore」→ 该 app 立即从列表隐藏并落盘（记录留在 JSON，标 `"ignored": true`）。无取消入口——手删该行的 `ignored` 字段并重启即恢复。
- 界面固定英文，无国际化 / 多语言切换。
- 数据文件：`~/.config/jj-apps/apps.json`（pretty JSON，可手改）。

## 架构

- **数据唯一来源 = JSON**：启动只读 `~/.config/jj-apps/apps.json` → 排序 → 立即渲染（首帧即有内容），不读任何系统库、不阻塞于扫描。所有操作（搜索 / 排序 / 展示）都基于这份内存数据。
- **`last_focus` = 最近一次前台使用结束时间**：从 `knowledgeC.db` 的 `/app/usage` 取各 bundle 的 `MAX(ZENDDATE)`，与 JSON 历史值取 `max` 累积突破系统保留窗口；读取需要 Full Disk Access。
- **后台校正（stale-while-revalidate）**：渲染缓存后，后台扫描 `/Applications` + `/System/Applications` + `~/Applications` 及各自 Utilities 的顶层 `.app`，同时查询 KnowledgeC，回主线程合并落盘；不挡首帧。
- **`last_update` = `.app/Contents` 目录 birthtime**：文件系统 syscall（`FileManager.creationDate` → `getattrlist`），与 KnowledgeC 无关。选内层 `Contents/` 而非顶层 `.app`：具体文件（Info.plist / binary）时间戳是打包时刻（`copyfile` 保留源 mtime），只有目录 birthtime 是本机创建时刻——首装 = 落盘时刻；Sparkle / MAS 更新替换整个 Contents → birthtime 重置为更新时刻。顶层 `.app` 的 mtime 会被 quarantine xattr 等无关噪声触发，故不用。每次 rebuild 以 scanner 结果覆盖，不与 JSON 已存值 `max`-merge（文件系统当下即真相；卸载重装应刷新）。
- **写盘安全**：写入统一在主线程串行，后台扫描本身不落盘。原子写（tmp + fsync + rename）+ `.bak`；app 是唯一写入方，不需 flock / FSEvents。
- **时间双字段**：主字段 epoch 毫秒（排序用）+ `*_jst` 日本时间可读串（JST=UTC+9 恒定，供人阅读 JSON）。
- 技术：Swift + AppKit 纯源码（无 SwiftUI / Storyboard / xib，SwiftPM executable + `defaultIsolation(MainActor)`）；系统 SQLite3；英文文案直接写在调用点，无本地化层；零第三方依赖。

## 数据契约

顶层 `{ "version": 1, "apps": [ ... ] }`。app 记录字段（缺字段读取方按默认兜底）：

<!-- prettier-ignore -->
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `path` | string | 记录主键（bundleId 可能多份安装，path 唯一） |
| `bundle_id` | string | 应用 bundle 标识（GUI 展示 + 搜索用） |
| `name` | string | `CFBundleDisplayName ?? CFBundleName ?? 文件名` |
| `last_focus` | number | 最近一次前台使用区间结束时间，epoch 毫秒；无记录 = `0`（默认排序键） |
| `last_focus_jst` | string | `last_focus` 的日本时间可读串；`0` 时为 `""` |
| `last_update` | number | `.app/Contents` 目录 birthtime，epoch 毫秒；读不到 = `0`（可切换为排序键） |
| `last_update_jst` | string | `last_update` 的日本时间可读串；`0` 时为 `""` |
| `added` | number | 本工具首次记录该 app 的 epoch 毫秒 |
| `added_jst` | string | `added` 的日本时间可读串 |
| `ignored` | bool | 用户手动忽略：从列表隐藏。**仅 `true` 时写盘**（缺字段 = `false`）；删该字段并重启即取消忽略 |

- 默认排序键 `last_focus` 降序；点击列头可切换到 `last_update` 或 toggle 升 / 降序。相等（含大量 `0`）用 `name` 升序兜底，保证确定序。
- `ignored` 展示层过滤：内存全量数据仍持 ignored 记录（落盘保留标记），仅列表 / 计数排除。⌘R 扫描以内存标记 OR-merge，扫描进行中的 ignore 不丢失。

## 项目结构

- `VERSION` — 单一版本源；`package.sh` 注入 `Info.plist`
- `Package.swift` — SwiftPM executable（macOS 13+）
- `package.sh` — 构建 + 组装 `.app` + ad-hoc 签名 + 装 /Applications（无参数）
- `Sources/jj-apps/` — Swift 源码（数据层 `AppRecord` / `AppScanner` / `KnowledgeDB` / `AppRepository` / GUI `MainViewController` 等）
- `Resources/Info.plist.in` — bundle 模板（`@VERSION@` 占位）
