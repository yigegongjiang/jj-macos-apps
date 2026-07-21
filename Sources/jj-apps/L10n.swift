import Foundation

// 集中英文字符串表。当前 app 足够简单，仅英文、无国际化（不做多语言切换）。
// 保留集中入口只为避免字面量散落各处，非本地化抽象。
nonisolated enum L10n {
    static let appName = "jj-apps"

    // MARK: - 主菜单
    static func menuAbout(_ app: String) -> String { "About \(app)" }
    static func menuHide(_ app: String) -> String { "Hide \(app)" }
    static var menuHideOthers: String { "Hide Others" }
    static var menuShowAll: String { "Show All" }
    static func menuQuit(_ app: String) -> String { "Quit \(app)" }
    static var menuEdit: String { "Edit" }
    static var menuCut: String { "Cut" }
    static var menuCopy: String { "Copy" }
    static var menuPaste: String { "Paste" }
    static var menuSelectAll: String { "Select All" }
    static var menuView: String { "View" }
    static var menuRefresh: String { "Refresh" }
    static var menuFind: String { "Find" }
    static var menuWindow: String { "Window" }
    static var menuMinimize: String { "Minimize" }
    static var menuZoom: String { "Zoom" }

    // MARK: - 主界面
    static var searchPlaceholder: String { "Search apps" }
    static var refresh: String { "Refresh" }
    static func autoExitMinutes(_ m: Int) -> String { "Auto-exit \(m) min" }
    static var open: String { "Open" }
    static var revealInFinder: String { "Reveal in Finder" }
    static var addToIgnore: String { "Add to Ignore" }
    static var neverUsed: String { "Never used" }
    static var sortHint: String { "Sorted by last used" }
    static var columnApp: String { "Application" }
    static var columnLastUsed: String { "Last Used" }
    static var columnLastUpdate: String { "Last Update" }
    static var never: String { "—" }
    static func statusTotal(_ n: Int) -> String { n == 1 ? "1 app" : "\(n) apps" }
    static func statusFiltered(shown: Int, total: Int) -> String { "\(shown) / \(total) apps" }
    static var scanning: String { "Scanning…" }

    // MARK: - FDA banner
    static var fdaTitle: String { "Full Disk Access required for Last Used" }
    static var fdaHint: String { "Grant access to jj-apps, then click Recheck." }
    static var fdaOpenSettings: String { "Open Full Disk Access" }
    static var fdaRecheck: String { "Recheck" }
}
