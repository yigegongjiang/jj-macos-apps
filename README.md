```When Editing
本文档 = 工程总览（价值 / 用法 / 架构 / 契约 / 结构）; MUST NOT 塞发布流程 (→ workflow.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 编写规范
```

# jj-macos-apps

macOS 应用管理器：扫本机 app、按最近前台时间排序、即时搜索、双击启动。Swift + AppKit 纯源码，单 JSON 数据文件，零第三方依赖。

## 使用

- 构建装机：`./package.sh` -> 见 [workflow.md](./workflow.md)
- 启动秒开：先读 JSON 缓存渲染，后台再 scan 补新装 / 删卸载
- 搜索：多词 AND，命中 name / bundleId / path
- 列表 3 列：App / Last Used / Last Update；点日期列头切换排序键，再点同列 toggle 升 / 降；默认 `last_focus` 降序
- 快捷：双击 or Enter 启动、右键 Reveal / Add to Ignore、⌘R 刷新、⌘F 搜索
- Ignore：右键 Add to Ignore -> 立即隐藏 + 落盘 `"ignored": true`；取消 = 手删 JSON 该字段 + 重启
- 界面固定英文；数据 = `~/.config/jj-macos-apps/apps.json`（pretty JSON，可手改）

## 架构

- **JSON = 唯一数据源**：启动只读它 -> 排序 -> 立即渲染；不阻塞 scan / 不读系统库；搜索 / 排序全基于这份内存
- **`last_focus` 来源 = knowledgeC**：`/app/usage` 各 bundle 的 `MAX(ZENDDATE)`，与 JSON 历史值取 `max`（累积突破系统保留窗口）；需 Full Disk Access
- **后台校正 (stale-while-revalidate)**：渲染缓存后再 scan `/Applications` + `/System/Applications` + `~/Applications` 及各自 Utilities 顶层 `.app` + KnowledgeC，回主线程合并落盘
- **`last_update` = `.app/Contents` birthtime**：具体文件 mtime 是打包时刻（`copyfile` 保留源 mtime），只有目录 birthtime 是本机 syscall 生成 -> 首装即落盘时刻；Sparkle / MAS 更新替换整个 Contents -> 重置为更新时刻。顶层 `.app` mtime 会被 quarantine xattr 噪声触发，故不用。scanner 结果直接覆盖（不 max-merge，卸载重装应刷新）
- **写盘串行安全**：主线程唯一写入方；原子写 (tmp + fsync + rename) + `.bak`；不需 flock / FSEvents
- **双字段时间**：epoch ms（排序）+ `*_jst`（人读，JST=UTC+9 恒定）
- **技术栈**：Swift + AppKit（无 SwiftUI / Storyboard / xib）+ SwiftPM executable + `defaultIsolation(MainActor)` + 系统 SQLite3；文案硬编码英文；零第三方依赖

## 数据契约

顶层 `{ "version": 1, "apps": [...] }`。app 字段（读取方按默认兜底）：

<!-- prettier-ignore -->
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `path` | string | 主键（同 bundleId 可多份，path 唯一） |
| `bundle_id` | string | GUI 展示 + 搜索 |
| `name` | string | `CFBundleDisplayName ?? CFBundleName ?? 文件名` |
| `last_focus` | number | 最近前台结束时刻 epoch ms；无 = `0`（默认排序键） |
| `last_focus_jst` | string | JST 可读串；`0` 时为 `""` |
| `last_update` | number | `.app/Contents` birthtime epoch ms；读不到 = `0` |
| `last_update_jst` | string | JST 可读串；`0` 时为 `""` |
| `added` | number | 本工具首次记录 epoch ms |
| `added_jst` | string | JST 可读串 |
| `ignored` | bool | 手动忽略：从列表隐藏；**仅 `true` 时写盘**；删该字段 + 重启即取消 |

- 排序相等（含大量 `0`）用 `name` 升序兜底 -> 确定序
- `ignored` 展示层过滤：内存持全量 + 落盘保留标记；⌘R 扫描以内存标记 OR-merge，不丢失

## 项目结构

- `VERSION` — 单一版本源；`package.sh` 注入 `Info.plist`
- `Package.swift` — SwiftPM executable（macOS 13+）
- `package.sh` — Release 构建 + 组装 `.app` + ad-hoc 签名 + 装 `/Applications`
- `Sources/jj-macos-apps/` — Swift 源码
- `Resources/Info.plist.in` — bundle 模板（`@VERSION@` 占位）
