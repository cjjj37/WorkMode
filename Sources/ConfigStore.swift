import Foundation

extension Notification.Name {
    static let workModeConfigDidChange = Notification.Name("WorkModeConfigDidChange")
}

/// 配置中心：读写 ~/Library/Application Support/WorkMode/modes.json
final class ConfigStore {

    static let shared = ConfigStore()

    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        return base.appendingPathComponent("WorkMode", isDirectory: true)
    }()

    static var fileURL: URL {
        appSupportDir.appendingPathComponent("modes.json")
    }

    private(set) var config: AppConfig = AppConfig(modes: [])

    private init() {
        ensureDirectory()
        load()
    }

    // MARK: - 读写

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: Self.appSupportDir,
                                                 withIntermediateDirectories: true)
    }

    func load() {
        ensureDirectory()
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        } else {
            config = Seed.makeDefaultConfig()
            save(silent: true)
        }
    }

    func save(silent: Bool = false) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
        if !silent {
            NotificationCenter.default.post(name: .workModeConfigDidChange, object: self)
        }
    }

    // MARK: - 查询

    func mode(id: UUID) -> LaunchMode? {
        config.modes.first { $0.id == id }
    }

    func app(modeID: UUID, appID: UUID) -> AppItem? {
        mode(id: modeID)?.apps.first { $0.id == appID }
    }

    func indexOfMode(_ id: UUID) -> Int? {
        config.modes.firstIndex { $0.id == id }
    }

    // MARK: - 模式增删查改

    @discardableResult
    func addMode(name: String = "新模式", icon: String = "🚀") -> LaunchMode {
        var mode = LaunchMode(name: name, icon: icon)
        // 避免重名
        var n = 1
        var candidate = name
        while config.modes.contains(where: { $0.name == candidate }) {
            n += 1
            candidate = "\(name) \(n)"
        }
        mode.name = candidate
        config.modes.append(mode)
        save()
        return mode
    }

    func removeMode(_ id: UUID) {
        config.modes.removeAll { $0.id == id }
        save()
    }

    func updateMode(_ id: UUID, name: String? = nil, icon: String? = nil) {
        guard let idx = indexOfMode(id) else { return }
        if let name = name { config.modes[idx].name = name }
        if let icon = icon { config.modes[idx].icon = icon }
        save()
    }

    // MARK: - 应用增删

    func addApps(_ urls: [URL], to modeID: UUID) -> Int {
        guard let idx = indexOfMode(modeID) else { return 0 }
        var added = 0
        let fm = FileManager.default
        for url in urls {
            let path = url.path
            guard path.hasSuffix(".app"), fm.fileExists(atPath: path) else { continue }
            guard !config.modes[idx].apps.contains(where: { $0.path == path }) else { continue }
            let bundle = Bundle(url: url)
            let display = fm.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
            let item = AppItem(name: display, path: path, bundleID: bundle?.bundleIdentifier)
            config.modes[idx].apps.append(item)
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    func removeApp(modeID: UUID, appID: UUID) {
        guard let idx = indexOfMode(modeID) else { return }
        config.modes[idx].apps.removeAll { $0.id == appID }
        save()
    }
}
