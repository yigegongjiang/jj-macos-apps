import Foundation

// 数据目录固定 ~/.config/jj-apps（XDG 习惯）
nonisolated enum AppPaths {
    static func dataDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/jj-apps", isDirectory: true)
    }

    static func dataFile() -> URL {
        dataDirectory().appendingPathComponent("apps.json", isDirectory: false)
    }
}
