import AppKit

/// 带 modeID 标记的菜单，用于在 menuNeedsUpdate 时区分是哪个模式的子菜单
final class ModeMenu: NSMenu {
    var modeID: UUID?
}

/// 菜单栏控制器：负责状态栏图标 + 动态菜单
final class MenuBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let rootMenu = ModeMenu(title: "WorkMode")

    var onOpenSettings: (() -> Void)?
    var onOpenSettingsForMode: ((UUID) -> Void)?

    private struct LaunchRef {
        let modeID: UUID
        let appID: UUID
    }

    private var originalImage: NSImage?

    override init() {
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "bolt.fill",
                                accessibilityDescription: "模式启动器")
            image?.isTemplate = true
            originalImage = image
            button.image = image
            button.toolTip = "模式启动器 — 点击开启模式"
        }
        rootMenu.delegate = self
        statusItem.menu = rootMenu

        rebuildRoot()
    }

    // MARK: - 菜单构建

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === rootMenu {
            rebuildRoot()
        } else if let modeMenu = menu as? ModeMenu,
                  let id = modeMenu.modeID,
                  let mode = ConfigStore.shared.mode(id: id) {
            rebuild(modeMenu: modeMenu, mode: mode)
        }
    }

    func refresh() {
        rebuildRoot()
    }

    private func rebuildRoot() {
        rootMenu.removeAllItems()

        let modes = ConfigStore.shared.config.modes

        if modes.isEmpty {
            let empty = NSMenuItem(title: "还没有配置任何模式", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            rootMenu.addItem(empty)
        } else {
            for mode in modes {
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                item.attributedTitle = Self.rootTitle(for: mode)
                let submenu = ModeMenu(title: mode.name)
                submenu.modeID = mode.id
                submenu.delegate = self
                rootMenu.addItem(item)
                rootMenu.setSubmenu(submenu, for: item)
                rebuild(modeMenu: submenu, mode: mode)
            }
        }

        rootMenu.addItem(NSMenuItem.separator())

        let autostart = NSMenuItem(title: "开机自动启动",
                                   action: #selector(toggleAutostart(_:)),
                                   keyEquivalent: "")
        autostart.target = self
        autostart.state = LoginItem.isEnabled ? .on : .off
        rootMenu.addItem(autostart)

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settings.target = self
        rootMenu.addItem(settings)

        let quit = NSMenuItem(title: "退出模式启动器", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        rootMenu.addItem(quit)
    }

    private func rebuild(modeMenu: NSMenu, mode: LaunchMode) {
        modeMenu.removeAllItems()

        let total = mode.apps.count
        let running = Launcher.runningCount(in: mode)
        let pending = total - running

        let head = NSMenuItem(title: "", action: #selector(launchMode(_:)), keyEquivalent: "")
        head.target = self
        head.representedObject = mode.id.uuidString

        if total == 0 {
            head.attributedTitle = Self.disabledTitle("这个模式还没添加应用")
            head.isEnabled = false
        } else if pending == 0 {
            head.attributedTitle = Self.disabledTitle("全部 \(total) 个应用都已在运行")
            head.isEnabled = false
        } else {
            let text = NSMutableAttributedString(
                string: "▶  一键启动",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
            text.append(NSAttributedString(
                string: "   待启动 \(pending) · 共 \(total)",
                attributes: [.font: NSFont.systemFont(ofSize: 11),
                             .foregroundColor: NSColor.secondaryLabelColor]))
            head.attributedTitle = text
        }
        modeMenu.addItem(head)

        if total > 0 {
            modeMenu.addItem(NSMenuItem.separator())
            for app in mode.apps {
                let isRunning = Launcher.isRunning(app)
                let isPending = Launcher.isPending(app)     // 刚点过、还没起来
                let item = NSMenuItem(title: app.name,
                                      action: #selector(launchApp(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = LaunchRef(modeID: mode.id, appID: app.id)
                item.state = isRunning ? .on : (isPending ? .mixed : .off)
                if isPending && !isRunning {
                    item.toolTip = "启动中…"
                }

                let icon = NSWorkspace.shared.icon(forFile: app.path)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon

                if !FileManager.default.fileExists(atPath: app.path) {
                    item.attributedTitle = NSAttributedString(
                        string: app.name,
                        attributes: [.foregroundColor: NSColor.systemRed])
                    item.toolTip = "找不到这个应用了：\(app.path)"
                }
                modeMenu.addItem(item)
            }
        }

        modeMenu.addItem(NSMenuItem.separator())
        let edit = NSMenuItem(title: "编辑「\(mode.name)」…",
                              action: #selector(openModeSettings(_:)),
                              keyEquivalent: "")
        edit.target = self
        edit.representedObject = mode.id.uuidString
        modeMenu.addItem(edit)
    }

    // MARK: - 标题样式

    private static func rootTitle(for mode: LaunchMode) -> NSAttributedString {
        let running = Launcher.runningCount(in: mode)
        let total = mode.apps.count
        let text = NSMutableAttributedString(
            string: "\(mode.icon)  \(mode.name)",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)])
        if total > 0 {
            text.append(NSAttributedString(
                string: "   \(running)/\(total)",
                attributes: [.font: NSFont.systemFont(ofSize: 11),
                             .foregroundColor: NSColor.secondaryLabelColor]))
        }
        return text
    }

    private static func disabledTitle(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string,
                           attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                                        .font: NSFont.systemFont(ofSize: 13)])
    }

    // MARK: - 动作

    @objc private func launchMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw),
              let mode = ConfigStore.shared.mode(id: id) else { return }
        let count = Launcher.launch(mode: mode)
        flash()
        NSLog("WorkMode: 触发模式「\(mode.name)」，实际启动 \(count) 个")
    }

    @objc private func launchApp(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? LaunchRef,
              let app = ConfigStore.shared.app(modeID: ref.modeID, appID: ref.appID) else { return }
        Launcher.launch(app: app)
        flash()
    }

    @objc private func toggleAutostart(_ sender: NSMenuItem) {
        let enable = !LoginItem.isEnabled
        let ok = LoginItem.setEnabled(enable)
        sender.state = LoginItem.isEnabled ? .on : .off
        if !ok {
            let alert = NSAlert()
            alert.messageText = enable ? "开启开机自启失败" : "关闭开机自启失败"
            alert.informativeText = "可以手动添加：系统设置 → 通用 → 登录项与扩展 → 把 WorkMode 加进去。"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        onOpenSettings?()
    }

    @objc private func openModeSettings(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        onOpenSettingsForMode?(id)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: - 视觉反馈

    /// 启动时让菜单栏图标短暂变成「✓」，给人一个明确的反馈
    private func flash() {
        guard let button = statusItem.button else { return }
        let done = NSImage(systemSymbolName: "checkmark.circle.fill",
                           accessibilityDescription: nil)
        done?.isTemplate = true
        button.image = done
        button.contentTintColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self = self else { return }
            self.statusItem.button?.image = self.originalImage
            self.statusItem.button?.contentTintColor = nil
        }
    }
}
