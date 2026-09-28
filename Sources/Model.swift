import Foundation

// MARK: - 数据模型

/// 模式里的一个应用条目
struct AppItem: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String          // 显示名（本地化后的名字）
    var path: String          // .app 的完整路径
    var bundleID: String?     // 用于判断是否正在运行

    init(id: UUID = UUID(), name: String, path: String, bundleID: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.bundleID = bundleID
    }
}

/// 一个「模式」，例如 工作模式 / 娱乐模式
struct LaunchMode: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var icon: String          // emoji
    var apps: [AppItem]

    init(id: UUID = UUID(), name: String, icon: String, apps: [AppItem] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.apps = apps
    }
}

struct AppConfig: Codable {
    var modes: [LaunchMode]
}

// MARK: - 首次运行的默认种子数据

enum Seed {

    /// 首次启动只生成两个空模式：不扫描用户装了什么，应用由用户自己添加
    static func makeDefaultConfig() -> AppConfig {
        AppConfig(modes: [
            LaunchMode(name: "工作模式", icon: "💼", apps: []),
            LaunchMode(name: "娱乐模式", icon: "🎮", apps: [])
        ])
    }
}
