import AppKit
import Foundation

// 扫主机 Applications 目录顶层 .app（不下钻，避免 helper / 内嵌 app 噪声）。
// Utilities 单独作为扫描根显式纳入（Terminal / Console 等住此，非 helper）。
nonisolated struct ScannedApp: Sendable {
    var path: String
    var bundleId: String
    var name: String
    var lastUpdate: Int64
}

nonisolated enum AppScanner {
    private static func roots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    static func scan() -> [ScannedApp] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [ScannedApp] = []
        for root in roots() {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "app" {
                let path = url.standardizedFileURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                guard let app = read(at: url, path: path) else { continue }
                result.append(app)
            }
        }
        return result
    }

    private static func read(at url: URL, path: String) -> ScannedApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary
        let bundleId = bundle.bundleIdentifier ?? ""
        let name = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        // last_update = <path>/Contents birthtime：文件 mtime 是打包时刻（copyfile 保源 mtime），
        // 只有目录 birthtime 是本机 syscall 生成 -> 首装 / Sparkle / MAS 更新时才刷新；
        // 顶层 .app mtime 会被 quarantine xattr 等噪声触发，故选内层 Contents。
        let contentsPath = url.appendingPathComponent("Contents").path
        let attrs = try? FileManager.default.attributesOfItem(atPath: contentsPath)
        let lastUpdate: Int64 = (attrs?[.creationDate] as? Date)
            .map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0
        return ScannedApp(path: path, bundleId: bundleId, name: name, lastUpdate: lastUpdate)
    }
}
