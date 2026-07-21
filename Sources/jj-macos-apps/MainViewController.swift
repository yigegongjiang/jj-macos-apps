import AppKit

// 主界面：搜索框 + 刷新 + FDA 横幅 + 3 列表格（App / Last Used / Last Update）。
// 列头排序：native NSTableView sortDescriptors，默认 last_focus 降序，再点同列 toggle 升 / 降，相等用 name 兜底。
final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let searchField = NSSearchField()
    private let refreshButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    // 空闲 idleSeconds 秒退出；任意本 app 交互重置倒计时
    private let countdownLabel = NSTextField(labelWithString: "")
    private static let idleSeconds = 300
    private var autoExitDeadline: Date?
    private var countdownTimer: Timer?
    private var activityMonitor: Any?

    private let bannerView = NSView()
    private var bannerHeight: NSLayoutConstraint!
    private let scrollView = NSScrollView()
    private let tableView = AppsTableView()

    private var allApps: [AppRecord] = []
    private var filtered: [AppRecord] = []
    private var iconCache: [String: NSImage] = [:]
    private var isRefreshing = false

    // 与列 identifier / AppRecord JSON key 对齐
    private static let sortKeyLastFocus  = "last_focus"
    private static let sortKeyLastUpdate = "last_update"

    override func loadView() {
        let root = NSView()

        searchField.placeholderString = "Search apps"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refresh(_:))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)   // 等宽 -> 每秒跳动不抖
        countdownLabel.textColor = .secondaryLabelColor
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(searchField)
        root.addSubview(statusLabel)
        root.addSubview(spinner)
        root.addSubview(countdownLabel)
        root.addSubview(refreshButton)

        buildBanner()
        root.addSubview(bannerView)

        tableView.rowHeight = 30
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(openSelected)
        tableView.target = self
        tableView.onActivate = { [weak self] _ in self?.openSelected() }
        tableView.menu = buildRowMenu()

        // App 列：随窗口伸缩，不参与排序
        let appCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appCol.title = "Application"
        appCol.resizingMask = .autoresizingMask
        appCol.minWidth = 200
        appCol.width = 420
        tableView.addTableColumn(appCol)

        let focusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(Self.sortKeyLastFocus))
        focusCol.title = "Last Used"
        focusCol.minWidth = 130
        focusCol.width = 150
        focusCol.resizingMask = .userResizingMask
        focusCol.sortDescriptorPrototype = NSSortDescriptor(key: Self.sortKeyLastFocus, ascending: false)
        tableView.addTableColumn(focusCol)

        let updateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(Self.sortKeyLastUpdate))
        updateCol.title = "Last Update"
        updateCol.minWidth = 130
        updateCol.width = 150
        updateCol.resizingMask = .userResizingMask
        updateCol.sortDescriptorPrototype = NSSortDescriptor(key: Self.sortKeyLastUpdate, ascending: false)
        tableView.addTableColumn(updateCol)

        tableView.sortDescriptors = [NSSortDescriptor(key: Self.sortKeyLastFocus, ascending: false)]

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            searchField.widthAnchor.constraint(equalToConstant: 260),

            refreshButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            refreshButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            countdownLabel.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8),
            countdownLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            spinner.trailingAnchor.constraint(equalTo: countdownLabel.leadingAnchor, constant: -8),
            spinner.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            statusLabel.trailingAnchor.constraint(equalTo: spinner.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            bannerView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            bannerView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: bannerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        bannerHeight = bannerView.heightAnchor.constraint(equalToConstant: 0)
        bannerHeight.isActive = true
        bannerView.isHidden = true

        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        renderFromCache()   // 秒开：先吃 JSON 缓存
        refresh(nil)        // 再后台 scan 校正
        startActivityMonitor()
        scheduleAutoExit()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(searchField)
    }

    // MARK: - FDA banner

    private func buildBanner() {
        bannerView.wantsLayer = true
        bannerView.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.15).cgColor
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        let warning = NSImageView()
        warning.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        warning.contentTintColor = .systemOrange
        warning.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Full Disk Access required for Last Used")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString: "Grant access to jj-macos-apps, then click Recheck.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byTruncatingTail
        hint.translatesAutoresizingMaskIntoConstraints = false

        let open = NSButton(title: "Open Full Disk Access", target: self, action: #selector(openFDASettings))
        open.bezelStyle = .rounded
        open.translatesAutoresizingMaskIntoConstraints = false

        let recheck = NSButton(title: "Recheck", target: self, action: #selector(refresh(_:)))
        recheck.bezelStyle = .rounded
        recheck.translatesAutoresizingMaskIntoConstraints = false

        for view in [warning, title, hint, open, recheck] { bannerView.addSubview(view) }
        NSLayoutConstraint.activate([
            warning.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 12),
            warning.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            warning.widthAnchor.constraint(equalToConstant: 18),
            warning.heightAnchor.constraint(equalToConstant: 18),

            title.leadingAnchor.constraint(equalTo: warning.trailingAnchor, constant: 8),
            title.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: open.leadingAnchor, constant: -8),

            recheck.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -12),
            recheck.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            open.trailingAnchor.constraint(equalTo: recheck.leadingAnchor, constant: -8),
            open.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
        ])
    }

    private func setBanner(visible: Bool) {
        bannerView.isHidden = !visible
        bannerHeight.constant = visible ? 52 : 0
    }

    // MARK: - 自动退出

    private func scheduleAutoExit() {
        autoExitDeadline = Date().addingTimeInterval(TimeInterval(Self.idleSeconds))
        updateCountdownLabel()   // 立即刷新，避免首个 tick 前 1s 空窗
        if countdownTimer == nil {
            // 单个常驻 timer；交互只后移 deadline，不重建。
            // target-action 而非 block：规避 @Sendable 闭包对 self 的并发约束。
            // .common：菜单展开等 tracking 期间仍计时。
            let t = Timer(timeInterval: 1, target: self,
                          selector: #selector(tickCountdown), userInfo: nil, repeats: true)
            RunLoop.main.add(t, forMode: .common)
            countdownTimer = t
        }
    }

    @objc private func tickCountdown() {
        guard let deadline = autoExitDeadline else { return }
        if Date() >= deadline { NSApp.terminate(nil); return }
        updateCountdownLabel()
    }

    private func updateCountdownLabel() {
        guard let deadline = autoExitDeadline else { return }
        let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
        countdownLabel.stringValue = "Exit: \(remaining)s"
    }

    private func startActivityMonitor() {
        activityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { [weak self] event in
            self?.scheduleAutoExit()
            return event
        }
    }

    // MARK: - 排序

    private func sortedApps(_ apps: [AppRecord]) -> [AppRecord] {
        let d = tableView.sortDescriptors.first
        let key = d?.key ?? Self.sortKeyLastFocus
        let asc = d?.ascending ?? false
        return apps.sorted { a, b in
            let av: Int64
            let bv: Int64
            switch key {
            case Self.sortKeyLastUpdate: av = a.lastUpdate; bv = b.lastUpdate
            default:                     av = a.lastFocus;  bv = b.lastFocus
            }
            if av != bv { return asc ? av < bv : av > bv }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        allApps = sortedApps(allApps)
        applyFilter()
    }

    // MARK: - 启动缓存

    private func renderFromCache() {
        allApps = sortedApps(AppRepository.load().apps)
        applyFilter()
    }

    // MARK: - 后台 scan 校正

    @objc func refresh(_ sender: Any?) {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshButton.isEnabled = false
        spinner.startAnimation(nil)
        if allApps.isEmpty { statusLabel.stringValue = "Scanning…" }
        Task.detached(priority: .userInitiated) {
            let result = AppRepository.rebuild()
            await MainActor.run { self.apply(result) }
        }
    }

    // 合并 rebuild 快照与当前内存：last_focus 取较大值防回退；
    // ignored 取 OR（扫描进行中用户 ignore 的标记不被旧快照覆盖）；
    // last_update 以 rebuild 为准（文件系统当下即真相）。
    private func apply(_ result: AppRepository.RebuildResult) {
        isRefreshing = false
        refreshButton.isEnabled = true
        spinner.stopAnimation(nil)

        var priorByPath: [String: AppRecord] = [:]
        for r in allApps { priorByPath[r.path] = r }
        let merged = result.apps.map { r -> AppRecord in
            guard let p = priorByPath[r.path] else { return r }
            let focus = max(p.lastFocus, r.lastFocus)
            let ignored = p.ignored || r.ignored
            if focus == r.lastFocus && ignored == r.ignored { return r }
            return AppRecord(path: r.path, bundleId: r.bundleId, name: r.name,
                             lastFocus: focus, lastUpdate: r.lastUpdate, added: r.added, ignored: ignored)
        }
        allApps = sortedApps(merged)
        try? AppRepository.atomicWrite(AppStore(version: AppStore.currentVersion, apps: allApps))
        if case .ok = result.focus { setBanner(visible: false) } else { setBanner(visible: true) }
        applyFilter()
    }

    private func applyFilter() {
        // ignored 仅展示层过滤，allApps 持全量以便落盘保留标记
        let visible = allApps.filter { !$0.ignored }
        let q = searchField.stringValue
        filtered = q.isEmpty ? visible : visible.filter { $0.matchesSearch(q) }
        tableView.reloadData()
        if filtered.count == visible.count {
            statusLabel.stringValue = visible.count == 1 ? "1 app" : "\(visible.count) apps"
        } else {
            statusLabel.stringValue = "\(filtered.count) / \(visible.count) apps"
        }
    }

    // MARK: - 搜索

    func controlTextDidChange(_ obj: Notification) { applyFilter() }
    @objc func focusSearch(_ sender: Any?) { view.window?.makeFirstResponder(searchField) }

    // MARK: - 打开 / 访达 / Ignore

    @objc private func openSelected() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: filtered[row].path))
        // 不自记：目标 app 结束前台时 knowledgeC 会写，下次刷新读入
    }

    @objc private func revealSelected() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: filtered[row].path)])
    }

    @objc private func openFDASettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // 无会话内取消 ignore 入口：取消 = 用户手改 JSON 删该字段 + 重启（见 README 数据契约）
    @objc private func ignoreSelected() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let path = filtered[row].path
        guard let idx = allApps.firstIndex(where: { $0.path == path }) else { return }
        allApps[idx].ignored = true
        try? AppRepository.atomicWrite(AppStore(version: AppStore.currentVersion, apps: allApps))
        applyFilter()
    }

    private func buildRowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(openSelected), keyEquivalent: "")
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(revealSelected), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Add to Ignore", action: #selector(ignoreSelected), keyEquivalent: "")
        return menu
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let record = filtered[row]
        let colId = tableColumn?.identifier.rawValue ?? "app"
        switch colId {
        case "app":
            let c = (tableView.makeView(withIdentifier: NameCellView.reuseId, owner: self) as? NameCellView)
                ?? {
                    let v = NameCellView(); v.identifier = NameCellView.reuseId; return v
                }()
            c.configure(record, icon: icon(for: record.path))
            return c
        case Self.sortKeyLastUpdate:
            let c = dateCell()
            c.configure(epochMs: record.lastUpdate, jst: record.lastUpdateJst)
            return c
        default:
            let c = dateCell()
            c.configure(epochMs: record.lastFocus, jst: record.lastFocusJst)
            return c
        }
    }

    private func dateCell() -> DateCellView {
        (tableView.makeView(withIdentifier: DateCellView.reuseId, owner: self) as? DateCellView)
            ?? {
                let v = DateCellView(); v.identifier = DateCellView.reuseId; return v
            }()
    }

    private func icon(for path: String) -> NSImage {
        if let cached = iconCache[path] { return cached }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 32, height: 32)
        iconCache[path] = img
        return img
    }
}

// 回车键 = 双击（等价激活选中行）
final class AppsTableView: NSTableView {
    var onActivate: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {   // Return / Enter
            if selectedRow >= 0 { onActivate?(selectedRow); return }
        }
        super.keyDown(with: event)
    }
}
