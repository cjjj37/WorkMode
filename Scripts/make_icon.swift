// 生成一个 icns 应用图标：蓝紫渐变圆角底 + SF Symbol 闪电
// 用法：make_icon <输出路径.icns>
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.icns"

func tint(_ image: NSImage, color: NSColor) -> NSImage {
    let result = image.copy() as! NSImage
    result.lockFocus()
    color.set()
    NSRect(origin: .zero, size: result.size).fill(using: .sourceIn)
    result.unlockFocus()
    return result
}

func render(pointSize: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
        let inset = pointSize * 0.03
        let path = NSBezierPath(
            roundedRect: rect.insetBy(dx: inset, dy: inset),
            xRadius: pointSize * 0.22,
            yRadius: pointSize * 0.22
        )
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.24, green: 0.51, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.56, green: 0.37, blue: 0.96, alpha: 1)
        ])!
        gradient.draw(in: path, angle: -45)

        if let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
            let configuration = NSImage.SymbolConfiguration(pointSize: pointSize * 0.52, weight: .bold)
            let configured = symbol.withSymbolConfiguration(configuration) ?? symbol
            let tinted = tint(configured, color: .white)
            let symbolSize = tinted.size
            NSGraphicsContext.current?.imageInterpolation = .high
            tinted.draw(
                in: NSRect(
                    x: (pointSize - symbolSize.width) / 2,
                    y: (pointSize - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                ),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }
        return true
    }
}

// iconset 命名规范：(逻辑尺寸, 像素尺寸)
let entries: [(file: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WorkMode.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for entry in entries {
    let image = render(pointSize: CGFloat(entry.pixels))
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let bitmap = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("渲染失败: \(entry.file)\n".data(using: .utf8)!)
        continue
    }
    try? bitmap.write(to: iconsetURL.appendingPathComponent(entry.file))
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetURL.path, "-o", output]
try? task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    FileHandle.standardOutput.write("图标已生成: \(output)\n".data(using: .utf8)!)
} else {
    FileHandle.standardError.write("iconutil 失败\n".data(using: .utf8)!)
    exit(1)
}
