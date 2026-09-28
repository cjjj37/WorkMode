import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBar: MenuBarController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 触发配置加载（首次运行会生成默认模式）
        _ = ConfigStore.shared

        let menuBar = MenuBarController()
        menuBar.onOpenSettings = { [weak self] in self?.showSettings() }
        menuBar.onOpenSettingsForMode = { [weak self] id in self?.showSettings(modeID: id) }
        self.menuBar = menuBar

        NotificationCenter.default.addObserver(
            forName: .workModeConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuBar?.refresh()
        }

        // 开机自启默认开启：只在第一次运行时自动注册，之后完全尊重用户自己的开关
        let autostartKey = "WorkMode.didInitAutostart"
        if UserDefaults.standard.string(forKey: autostartKey) == nil {
            UserDefaults.standard.set("yes", forKey: autostartKey)
            if !LoginItem.isEnabled {
                LoginItem.setEnabled(true)
            }
        }

        // 首次使用：直接把设置界面弹出来，省得到处找入口
        let isFirstRun = UserDefaults.standard.string(forKey: "WorkMode.didLaunchBefore") == nil
        if isFirstRun {
            UserDefaults.standard.set("yes", forKey: "WorkMode.didLaunchBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showSettings()
            }
        }
    }

    func showSettings(modeID: UUID? = nil) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
        }
        settingsWindow?.show(modeID: modeID)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }
}

// MARK: - 命令行开关（方便脚本化控制开机自启）

func handleCommandLine() -> Bool {
    let args = CommandLine.arguments.dropFirst()
    if args.contains("--autostart-on") {
        print("开机自启: \(LoginItem.setEnabled(true) ? "已开启" : "开启失败")")
        return true
    }
    if args.contains("--autostart-off") {
        print("开机自启: \(LoginItem.setEnabled(false) ? "已关闭" : "关闭失败")")
        return true
    }
    if args.contains("--autostart-status") {
        print("开机自启: \(LoginItem.isEnabled ? "开启" : "关闭")")
        return true
    }
    return false
}

if handleCommandLine() { exit(0) }

// MARK: - 入口

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
// LSUIElement 风格的菜单栏应用：不出现在 Dock，也不需要主窗口
application.setActivationPolicy(.accessory)
application.run()
