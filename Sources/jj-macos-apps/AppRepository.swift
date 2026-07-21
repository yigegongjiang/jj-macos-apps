import Foundation

// 数据编排：JSON 缓存 = 秒开源；rebuild 只算不落盘，写盘统一在主线程串行。
// App 是唯一写入方 -> 无需 flock / FSWatcher；原子写 tmp+fsync+rename + .bak 防半写。
nonisolated enum AppRepository {
    struct RebuildResult: Sendable {
        var apps: [AppRecord]
        var focus: KnowledgeDB.FocusResult
    }

    // load JSON + scan 磁盘 + 查 knowledgeC 后合并：
    // - 现存 app 继承 JSON 的 added，last_focus 与 knowledgeC 取 max（累积突破保留窗口）
    // - 新 app: last_focus=0, added=now
    // - 已卸载记录随 scan 结果自然淘汰
    // - last_update 以 scanner 为准（文件系统当下即真相，不 max-merge；卸载重装应刷新）
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
            out.append(AppRecord(path: s.path, bundleId: s.bundleId, name: s.name,
                                 lastFocus: max(prior?.lastFocus ?? 0, focusByBundleId[s.bundleId] ?? 0),
                                 lastUpdate: s.lastUpdate,
                                 added: prior?.added ?? now,
                                 ignored: prior?.ignored ?? false))
        }
        return RebuildResult(apps: out, focus: focus)
    }

    static func load() -> AppStore {
        guard let data = try? Data(contentsOf: AppPaths.dataFile()) else { return .empty }
        // 解析失败返回空但不清盘：写盘前 .bak 备份磁盘现状，原始不丢
        return (try? JSONDecoder().decode(AppStore.self, from: data)) ?? .empty
    }

    // 原子写：tmp + fsync + POSIX rename 同目录内原子替换；.bak 保留上一份磁盘状态
    static func atomicWrite(_ store: AppStore) throws {
        let dir = AppPaths.dataDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let target = AppPaths.dataFile()
        let tmp = URL(fileURLWithPath: target.path + ".tmp")
        let bak = URL(fileURLWithPath: target.path + ".bak")

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(store)

        try data.write(to: tmp)
        let fh = try FileHandle(forUpdating: tmp)
        try fh.synchronize()   // 落盘持久化，防崩溃半写
        try fh.close()

        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: bak)
            try? FileManager.default.copyItem(at: target, to: bak)
        }

        guard rename(tmp.path, target.path) == 0 else {
            try? FileManager.default.removeItem(at: tmp)
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
