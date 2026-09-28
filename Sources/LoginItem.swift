import Foundation
import ServiceManagement

/// 开机自启开关
/// macOS 13+ 用官方的 SMAppService；macOS 12 或 SMAppService 失败时，退回写 LaunchAgent plist
enum LoginItem {

    private static let agentLabel = "com.local.workmode.launcher"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled { return true }
        }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        var ok = false
        var reason = ""

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                ok = true
            } catch {
                reason = "SMAppService 失败：\(error.localizedDescription)"
            }
        } else {
            reason = "系统低于 macOS 13"
        }

        // 官方接口不可用时退回 LaunchAgent
        if !ok {
            NSLog("WorkMode: 开机自启走 LaunchAgent 兜底（\(reason)）")
            ok = enabled ? writeAgent() : removeAgent()
        }

        // 关掉时顺手清掉可能残留的 LaunchAgent
        if !enabled { removeAgent() }

        NSLog("WorkMode: 开机自启 -> \(enabled) 结果：\(ok)")
        return ok
    }

    // MARK: - LaunchAgent 兜底

    private static func writeAgent() -> Bool {
        guard let executable = Bundle.main.executablePath else { return false }
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        do {
            try FileManager.default.createDirectory(
                at: agentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                           format: .xml,
                                                           options: 0)
            try data.write(to: agentURL, options: .atomic)
            return true
        } catch {
            NSLog("WorkMode: 写 LaunchAgent 失败：\(error.localizedDescription)")
            return false
        }
    }

    private static func removeAgent() -> Bool {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return true }
        do {
            try FileManager.default.removeItem(at: agentURL)
            return true
        } catch {
            NSLog("WorkMode: 删除 LaunchAgent 失败：\(error.localizedDescription)")
            return false
        }
    }
}
