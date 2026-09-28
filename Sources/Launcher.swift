import AppKit

/// 负责判断「是否已运行」以及真正启动应用
enum Launcher {

    // MARK: - 运行状态

    static func isRunning(_ item: AppItem) -> Bool {
        let apps = NSWorkspace.shared.runningApplications

        if let bundleID = item.bundleID, !bundleID.isEmpty,
           apps.contains(where: { $0.bundleIdentifier == bundleID }) {
            return true
        }

        let target = URL(fileURLWithPath: item.path).standardizedFileURL
        return apps.contains { $0.bundleURL?.standardizedFileURL == target }
    }

    static func runningCount(in mode: LaunchMode) -> Int {
        mode.apps.reduce(0) { $0 + (isRunning($1) ? 1 : 0) }
    }

    // MARK: - 启动中状态

    /// 刚点过启动、但 NSWorkspace 还没登记上来的应用（应用冷启动要几秒）
    private static var pendingUntil: [UUID: Date] = [:]
    private static let pendingWindow: TimeInterval = 12

    static func markPending(_ app: AppItem) {
        pendingUntil[app.id] = Date().addingTimeInterval(pendingWindow)
    }

    static func isPending(_ app: AppItem) -> Bool {
        guard let until = pendingUntil[app.id] else { return false }
        if until.timeIntervalSinceNow > 0 { return true }
        pendingUntil.removeValue(forKey: app.id)
        return false
    }

    // MARK: - 启动

    /// 启动单个应用。已经在跑的应用会直接被激活到最前面。
    static func launch(app: AppItem) {
        guard FileManager.default.fileExists(atPath: app.path) else {
            NSLog("WorkMode: 路径不存在，跳过 \(app.name)")
            return
        }
        let url = URL(fileURLWithPath: app.path)
        markPending(app)

        Task { @MainActor in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            do {
                try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            } catch {
                NSLog("WorkMode: 启动 \(app.name) 失败：\(error.localizedDescription)")
            }
        }
    }

    /// 一键启动整个模式：自动跳过已经在运行的应用，并错开一点时间避免系统卡顿
    static func launch(mode: LaunchMode, staggered: Bool = true) -> Int {
        var delay: TimeInterval = 0
        var count = 0
        for app in mode.apps {
            guard !isRunning(app), !isPending(app) else { continue }
            let fireDelay = delay
            if staggered && fireDelay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay) {
                    Launcher.launch(app: app)
                }
            } else {
                launch(app: app)
            }
            delay += 0.3
            count += 1
        }
        NSLog("WorkMode: 模式「\(mode.name)」启动了 \(count) 个应用，跳过 \(mode.apps.count - count) 个已在运行")
        return count
    }
}
