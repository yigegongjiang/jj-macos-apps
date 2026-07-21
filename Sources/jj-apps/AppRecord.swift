import Foundation

// 数据契约（对齐 jj-bookmark data-model 的双字段时间约定）：
// 每个时间点存两个字段——主字段 epoch 毫秒（机器排序用、source of truth）+ `*_jst`
// 日本时间可读串（纯供人阅读 JSON）。JST = UTC+9 恒定（日本无夏令时），由主字段无歧义换算。
// 记录主键 = path（同一 bundle_id 可能多份安装，path 唯一）；bundle_id 供展示 / 搜索。
nonisolated struct AppRecord: Codable, Sendable, Hashable, Identifiable {
    var path: String
    var bundleId: String
    var name: String
    var lastFocus: Int64        // 最近一次使用/聚焦时刻，epoch ms；从未记录为 0
    var lastFocusJst: String
    var lastUpdate: Int64       // .app/Contents 目录 birthtime（首装或最近整体替换）; 读不到为 0
    var lastUpdateJst: String
    var added: Int64            // 本工具首次记录该 app 的时刻，epoch ms
    var addedJst: String
    var ignored: Bool           // 用户手动忽略：不在列表展示；仅 true 时写盘（缺字段兜底 false）

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

    // 容错解码：缺字段兜底默认值（读取方可容错，与契约一致）。
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

    // 自定义编码：仅当 ignored == true 才写该 key，保持 JSON 干净（绝大多数 app 无此字段）。
    // 维护约束：今后新增字段 MUST 同步补进此处，否则静默丢字段。
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

    /// 多关键词搜索：按 Unicode 空白分词；全部词均须命中任意可搜索字段（名称 / bundleId / 路径）。
    func matchesSearch(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map { $0.lowercased() }
        if terms.isEmpty { return true }
        let searchable = [name, bundleId, path].joined(separator: " ").lowercased()
        return terms.allSatisfy { searchable.contains($0) }
    }
}

// 顶层文件结构 { version, apps: [...] }。
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

// epoch 毫秒 → 日本时间可读串 "YYYY-MM-DD HH:MM:SS+09:00"。epoch 0 → 空串（表示无记录）。
nonisolated enum JstTime {
    static func string(fromEpochMs ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        var cal = Calendar(identifier: .gregorian)
        // 固定 UTC+9，日本无夏令时，全年恒定偏移。
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d+09:00",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0,
                      c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}
