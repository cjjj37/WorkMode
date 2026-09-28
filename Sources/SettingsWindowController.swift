import AppKit

/// 设置窗口外壳
final class SettingsWindowController: NSWindowController {

    private var settingsVC: SettingsViewController?

    convenience init() {
        let vc = SettingsViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "模式启动器 · 设置"
        window.titlebarAppearsTransparent = false
        window.contentViewController = vc
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 660, height: 420)
        window.center()

        self.init(window: window)
        settingsVC = vc
    }

    func show(modeID: UUID? = nil) {
        if let id = modeID { settingsVC?.select(modeID: id) }
        else { settingsVC?.select(modeID: settingsVC?.currentSelection()) }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
