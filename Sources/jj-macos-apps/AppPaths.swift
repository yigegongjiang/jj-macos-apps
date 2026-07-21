import Foundation

// 数据目录固定 ~/.config/jj-macos-apps（XDG 习惯）
nonisolated enum AppPaths {
    static func dataDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/jj-macos-apps", isDirectory: true)
    }

    static func dataFile() -> URL {
        dataDirectory().appendingPathComponent("apps.json", isDirectory: false)
    }

    // v0.1.3 -> v0.1.4 一次性迁移：旧目录 ~/.config/jj-apps 存在且新目录缺席时整体搬迁
    // 幂等：新目录已存在即无操作；失败静默（用户重扫即可重建）
    static func migrateLegacyDataDirectoryIfNeeded() {
        let fm = FileManager.default
        let new = dataDirectory()
        let old = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/jj-apps", isDirectory: true)
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { return }
        try? fm.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.moveItem(at: old, to: new)
    }
}
