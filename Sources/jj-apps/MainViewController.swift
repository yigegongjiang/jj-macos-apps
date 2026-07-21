import AppKit

// 主界面：搜索框 + 刷新 + FDA 横幅 + 应用列表。
// 表格布局：3 列 = App / Last Used / Last Update；列头可点击排序（native NSTableView
// sortDescriptors）；默认按 last_focus 降序。首次点击列头进入该列 prototype (降序)，再次点击
// AppKit 自动 toggle 升/降。相等时 name 升序兜底保证确定序。
final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let searchField = NSSearchField()
    private let refreshButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    // 自动退出：空闲 idleSeconds 秒后退出，任意交互重置。只显示剩余秒数。
    private let countdownLabel = NSTextField(labelWithString: "")
    private static let idleSeconds = 300      // 空闲阈值（秒）
    private var autoExitDeadline: Date?       // 到点即退出的时刻；每次交互后移
    private var countdownTimer: Timer?        // 每秒刷新倒计时 + 到点触发退出
    private var activityMonitor: Any?

    private let bannerView = NSView()
    private var bannerHeight: NSLayoutConstraint!
    private let scrollView = NSScrollView()
    private let tableView = AppsTableView()

    private var allApps: [AppRecord] = []
    private var filtered: [AppRecord] = []
    private var iconCache: [String: NSImage] = [:]
    private var isRefreshing = false

    // 排序键（与列 identifier 对齐 / 与 AppRecord JSON key 对齐）
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

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)  // 数字等宽 → 每秒跳动不抖动
        countdownLabel.textColor = .secondaryLabelColor
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(searchField)
        root.addSubview(statusLabel)
        root.addSubview(spinner)
        root.addSubview(countdownLabel)
        root.addSubview(refreshButton)

        buildBanner()
        root.addSubview(bannerView)

        // 列表：3 列 + 列头（保留默认 NSTableHeaderView）
        tableView.rowHeight = 30
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(openSelected)
        tableView.target = self
        tableView.onActivate = { [weak self] _ in self?.openSelected() }
        tableView.menu = buildRowMenu()

        // App 列：图标 + 名字 + bundleId；随窗口宽度自动伸缩；不参与排序
        let appCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appCol.title = "Application"
        appCol.resizingMask = .autoresizingMask
        appCol.minWidth = 200
        appCol.width = 420
        tableView.addTableColumn(appCol)

        // Last Used 列：可点击排序，prototype 降序
        let focusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(Self.sortKeyLastFocus))
        focusCol.title = "Last Used"
        focusCol.minWidth = 130
        focusCol.width = 150
        focusCol.resizingMask = .userResizingMask
        focusCol.sortDescriptorPrototype = NSSortDescriptor(key: Self.sortKeyLastFocus, ascending: false)
        tableView.addTableColumn(focusCol)

        // Last Update 列：可点击排序，prototype 降序
        let updateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(Self.sortKeyLastUpdate))
        updateCol.title = "Last Update"
        updateCol.minWidth = 130
        updateCol.width = 150
        updateCol.resizingMask = .userResizingMask
        updateCol.sortDescriptorPrototype = NSSortDescriptor(key: Self.sortKeyLastUpdate, ascending: false)
        tableView.addTableColumn(updateCol)

        // 初始排序 = last_focus 降序
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
        refresh(nil)        // 再后台 scan 校正（补新装 / 删卸载）
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

        let hint = NSTextField(labelWithString: "Grant access to jj-apps, then click Recheck.")
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

    // MARK: - 自动退出（空闲计时；任意交互重置倒计时，仅真正空闲 N 分钟后退出）

    // 重置倒计时：deadline 推到「当前 + idleSeconds」，并保证每秒刷新的 timer 在跑。
    private func scheduleAutoExit() {
        autoExitDeadline = Date().addingTimeInterval(TimeInterval(Self.idleSeconds))
        updateCountdownLabel()  // 立即刷新，避免首个 tick 前 1s 空窗
        if countdownTimer == nil {
            // 单个常驻 repeating timer；交互只后移 deadline，不重建。
            // target-action 而非 block：规避 @Sendable 闭包捕获 self 的并发约束。
            // .common：菜单展开等 tracking 期间仍计时。
            let t = Timer(timeInterval: 1, target: self,
                          selector: #selector(tickCountdown), userInfo: nil, repeats: true)
            RunLoop.main.add(t, forMode: .common)
            countdownTimer = t
        }
    }

    @objc private func tickCountdown() {
        guard let deadline = autoExitDeadline else { return }
        if Date() >= deadline { NSApp.terminate(nil); return }  // RunLoop.main → 已在主线程
        updateCountdownLabel()
    }

    private func updateCountdownLabel() {
        guard let deadline = autoExitDeadline else { return }
        let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
        countdownLabel.stringValue = "Exit: \(remaining)s"
    }

    // 本 app 内任意键鼠交互重置倒计时；后台无事件即持续计时 → 空闲到点退出。
    private func startActivityMonitor() {
        activityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { [weak self] event in
            self?.scheduleAutoExit()
            return event
        }
    }

    // MARK: - 排序

    // 依当前 tableView.sortDescriptors 排序；相等用 name 升序兜底。
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

    // native 列头排序回调：点击列头 → AppKit 更新 tableView.sortDescriptors → 触发此方法。
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        allApps = sortedApps(allApps)
        applyFilter()
    }

    // MARK: - 启动：读 JSON 缓存立即渲染

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

    // rebuild 候选集与当前内存合并：last_focus 取较大者防回退；
    // last_update 以 rebuild 结果为准（文件系统当下即真相，不 max-merge）。
    private func apply(_ result: AppRepository.RebuildResult) {
        isRefreshing = false
        refreshButton.isEnabled = true
        spinner.stopAnimation(nil)

        // 内存 allApps 恒 ≥ rebuild 后台快照的新鲜度：last_focus 取较大者防回退，
        // ignored 取 OR（扫描进行中用户 ignore 的标记不能被旧快照覆盖丢失）。
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
        // 展示层过滤 ignored：allApps 仍持全量（含 ignored）以便落盘保留标记，仅显示层排除。
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

    // MARK: - 打开 / 访达

    @objc private func openSelected() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: filtered[row].path))
        // 不自记录：目标 app 结束本次前台使用后，由 knowledgeC 写入；下次刷新/重开读入。
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

    // 忽略选中 app：在全量 allApps 中按 path 反查置 ignored=true，落盘并刷新（展示层随即隐藏）。
    // 无会话内取消入口：取消 ignore = 用户手改 JSON 删该字段后重启（见 README 数据契约）。
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
        default:  // last_focus
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

// 列表：回车键激活选中行（等价双击）。
final class AppsTableView: NSTableView {
    var onActivate: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
            if selectedRow >= 0 { onActivate?(selectedRow); return }
        }
        super.keyDown(with: event)
    }
}
