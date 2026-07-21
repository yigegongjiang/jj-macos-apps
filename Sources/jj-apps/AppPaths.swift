import Foundation

// 数据目录：固定 ~/.config/jj-apps（遵循 XDG 习惯，与 jj-bookmark 一致的单一位置）。
nonisolated enum AppPaths {
    static func dataDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/jj-apps", isDirectory: true)
    }

    static func dataFile() -> URL {
        dataDirectory().appendingPathComponent("apps.json", isDirectory: false)
    }
}
