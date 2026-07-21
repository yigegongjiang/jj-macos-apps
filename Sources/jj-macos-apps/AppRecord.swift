import Foundation

// 数据契约：详见 README。主键 = path（同 bundleId 可多份，path 唯一）。
// 时间双字段：epoch ms（source of truth，排序用）+ `*_jst`（JST=UTC+9 恒定，供人阅读）
nonisolated struct AppRecord: Codable, Sendable, Hashable, Identifiable {
    var path: String
    var bundleId: String
    var name: String
    var lastFocus: Int64        // 最近前台结束 epoch ms；无 = 0
    var lastFocusJst: String
    var lastUpdate: Int64       // .app/Contents birthtime epoch ms；读不到 = 0
    var lastUpdateJst: String
    var added: Int64            // 本工具首次记录 epoch ms
    var addedJst: String
    var ignored: Bool           // 手动忽略；仅 true 时写盘（缺字段兜底 false）

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case path
        case bundleId = "bundle_id"
        case name
        case lastFocus = "last_focus"
        case lastFocusJst = "last_focus_jst"
        case lastUpdate = "last_update"
        case lastUpdateJst = "last_update_jst"
        case added
        case addedJst = "added_jst"
        case ignored
    }

    // 容错解码：缺字段兜底默认
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        bundleId = try c.decodeIfPresent(String.self, forKey: .bundleId) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        lastFocus = try c.decodeIfPresent(Int64.self, forKey: .lastFocus) ?? 0
        lastFocusJst = try c.decodeIfPresent(String.self, forKey: .lastFocusJst) ?? ""
        lastUpdate = try c.decodeIfPresent(Int64.self, forKey: .lastUpdate) ?? 0
        lastUpdateJst = try c.decodeIfPresent(String.self, forKey: .lastUpdateJst) ?? ""
        added = try c.decodeIfPresent(Int64.self, forKey: .added) ?? 0
        addedJst = try c.decodeIfPresent(String.self, forKey: .addedJst) ?? ""
        ignored = try c.decodeIfPresent(Bool.self, forKey: .ignored) ?? false
    }

    // 仅 ignored==true 才写该 key，保持 JSON 干净。新增字段 MUST 同步补进此处，否则静默丢失
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(path, forKey: .path)
        try c.encode(bundleId, forKey: .bundleId)
        try c.encode(name, forKey: .name)
        try c.encode(lastFocus, forKey: .lastFocus)
        try c.encode(lastFocusJst, forKey: .lastFocusJst)
        try c.encode(lastUpdate, forKey: .lastUpdate)
        try c.encode(lastUpdateJst, forKey: .lastUpdateJst)
        try c.encode(added, forKey: .added)
        try c.encode(addedJst, forKey: .addedJst)
        if ignored { try c.encode(true, forKey: .ignored) }
    }

    init(path: String, bundleId: String, name: String,
         lastFocus: Int64, lastUpdate: Int64, added: Int64, ignored: Bool = false) {
        self.path = path
        self.bundleId = bundleId
        self.name = name
        self.lastFocus = lastFocus
        self.lastFocusJst = JstTime.string(fromEpochMs: lastFocus)
        self.lastUpdate = lastUpdate
        self.lastUpdateJst = JstTime.string(fromEpochMs: lastUpdate)
        self.added = added
        self.addedJst = JstTime.string(fromEpochMs: added)
        self.ignored = ignored
    }

    /// 多词 AND：按 Unicode 空白分词，全词命中 name / bundleId / path 之一
    func matchesSearch(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map { $0.lowercased() }
        if terms.isEmpty { return true }
        let searchable = [name, bundleId, path].joined(separator: " ").lowercased()
        return terms.allSatisfy { searchable.contains($0) }
    }
}

nonisolated struct AppStore: Codable, Sendable {
    var version: Int
    var apps: [AppRecord]

    static let currentVersion = 1
    static let empty = AppStore(version: currentVersion, apps: [])

    enum CodingKeys: String, CodingKey { case version, apps }

    init(version: Int, apps: [AppRecord]) {
        self.version = version
        self.apps = apps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        apps = try c.decodeIfPresent([AppRecord].self, forKey: .apps) ?? []
    }
}

// epoch ms -> "YYYY-MM-DD HH:MM:SS+09:00"；0 -> 空串（无记录）
nonisolated enum JstTime {
    static func string(fromEpochMs ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!   // JST 恒定，日本无夏令时
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d+09:00",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0,
                      c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}
