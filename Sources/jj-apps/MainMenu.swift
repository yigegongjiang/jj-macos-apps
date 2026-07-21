import AppKit

// 程序化构建主菜单（无 xib）。App / Edit / View / Window 四组，够用即可。
nonisolated enum MainMenu {
    @MainActor
    static func build() -> NSMenu {
        let main = NSMenu()
        let app = L10n.appName

        // App 菜单
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: L10n.menuAbout(app),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let hide = appMenu.addItem(withTitle: L10n.menuHide(app),
                                   action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.keyEquivalentModifierMask = [.command]
        let hideOthers = appMenu.addItem(withTitle: L10n.menuHideOthers,
                                         action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L10n.menuShowAll,
                        action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: L10n.menuQuit(app),
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]

        // Edit 菜单（搜索框文本编辑需要标准剪贴板动作）
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: L10n.menuEdit)
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: L10n.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.menuSelectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // View 菜单（刷新 + 查找聚焦搜索框）
        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: L10n.menuView)
        viewItem.submenu = viewMenu
        viewMenu.addItem(withTitle: L10n.menuRefresh,
                         action: #selector(MainViewController.refresh(_:)), keyEquivalent: "r")
        viewMenu.addItem(withTitle: L10n.menuFind,
                         action: #selector(MainViewController.focusSearch(_:)), keyEquivalent: "f")

        // Window 菜单
        let winItem = NSMenuItem()
        main.addItem(winItem)
        let winMenu = NSMenu(title: L10n.menuWindow)
        winItem.submenu = winMenu
        winMenu.addItem(withTitle: L10n.menuMinimize,
                        action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: L10n.menuZoom, action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = winMenu

        return main
    }
}
