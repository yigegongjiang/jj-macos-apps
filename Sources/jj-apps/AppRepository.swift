import Foundation

// 数据编排：
// - 缓存 / 持久层 = ~/.config/jj-apps/apps.json；启动只读它即可秒开（见 MainViewController）。
// - last_focus 来源 = knowledgeC `/app/usage` 最近区间的 ZENDDATE，与同口径 JSON 历史值取 max 累积。
// - rebuild 不落盘：写盘统一由主线程 apply 执行，串行无竞态。
// - App 是唯一写入方 → 不需 flock / FSWatcher；仅原子写(tmp+fsync+rename)+.bak 防半写。
nonisolated enum AppRepository {
    struct RebuildResult: Sendable {
        var apps: [AppRecord]
        var focus: KnowledgeDB.FocusResult
    }

    // 后台计算：load JSON → scan 磁盘 → 合并（现存 app 继承 JSON 的 last_focus/added；
    // 新 app last_focus=0、added=now；已卸载的记录随扫描结果自然移除）。返回候选集，不落盘。
    static func rebuild() -> RebuildResult {
        let existing = load()
        let scanned = AppScanner.scan()
        let focus = KnowledgeDB.lastFocusByBundleId()
        let focusByBundleId: [String: Int64]
        if case .ok(let values) = focus { focusByBundleId = values } else { focusByBundleId = [:] }
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        var byPath: [String: AppRecord] = [:]
        for r in existing.apps { byPath[r.path] = r }

        var out: [AppRecord] = []
        out.reserveCapacity(scanned.count)
        for s in scanned {
            let prior = byPath[s.path]
            // 同口径 max-merge：突破 knowledgeC 保留窗口。
            // lastUpdate 以 scanner 结果为准（文件系统当下即真相；卸载重装应刷新为新值），不 max-merge。
            out.append(AppRecord(path: s.path, bundleId: s.bundleId, name: s.name,
                                 lastFocus: max(prior?.lastFocus ?? 0, focusByBundleId[s.bundleId] ?? 0),
                                 lastUpdate: s.lastUpdate,
                                 added: prior?.added ?? now,
                                 ignored: prior?.ignored ?? false))
        }
        return RebuildResult(apps: out, focus: focus)
    }

    // MARK: - 读

    static func load() -> AppStore {
        guard let data = try? Data(contentsOf: AppPaths.dataFile()) else { return .empty }
        // 解析失败不静默重建：返回空既有集；写盘前会先 .bak 备份磁盘现状，原始文件不丢。
        return (try? JSONDecoder().decode(AppStore.self, from: data)) ?? .empty
    }

    // MARK: - 原子写（tmp + fsync + rename）+ .bak

    static func atomicWrite(_ store: AppStore) throws {
        let dir = AppPaths.dataDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let target = AppPaths.dataFile()
        let tmp = URL(fileURLWithPath: target.path + ".tmp")
        let bak = URL(fileURLWithPath: target.path + ".bak")

        let enc = JSONEncoder()
        // pretty + 稳定键序 + 不转义斜杠（路径可读）；JSONEncoder 默认不转义非 ASCII（UTF-8）。
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(store)

        // 写临时文件并 fsync（落盘持久化，防崩溃半写）。
        try data.write(to: tmp)
        let fh = try FileHandle(forUpdating: tmp)
        try fh.synchronize()
        try fh.close()

        // 备份磁盘现状为 .bak（仅一份）。
        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: bak)
            try? FileManager.default.copyItem(at: target, to: bak)
        }

        // 原子覆盖：POSIX rename 同目录内原子替换。
        guard rename(tmp.path, target.path) == 0 else {
            try? FileManager.default.removeItem(at: tmp)
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
