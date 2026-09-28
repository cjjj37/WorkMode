import AppKit

/// 自己画选中背景：不受窗口是否激活、表格是否第一响应者影响，选中永远看得见
extension NSTableCellView {
    func prepareHighlightLayer() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
    }

    func applyHighlight(_ highlighted: Bool) {
        layer?.backgroundColor = highlighted
            ? NSColor.selectedControlColor.cgColor
            : NSColor.clear.cgColor
    }
}

/// 左侧模式列表的单元格：[emoji] 名称          N
final class ModeCellView: NSTableCellView {

    private let emojiLabel = NSTextField(labelWithString: "")
    private let nameLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        prepareHighlightLayer()

        emojiLabel.alignment = .center
        emojiLabel.font = .systemFont(ofSize: 15)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(emojiLabel)
        addSubview(nameLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            emojiLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            emojiLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emojiLabel.widthAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -6),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(mode: LaunchMode, selected: Bool) {
        emojiLabel.stringValue = mode.icon
        nameLabel.stringValue = mode.name
        countLabel.stringValue = "\(mode.apps.count)"
        applyHighlight(selected)
    }
}

/// 右侧应用列表的单元格：[icon] 名称           运行中
///                        /Applications/xxx.app
final class AppCellView: NSTableCellView {

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        prepareHighlightLayer()

        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        pathLabel.font = .systemFont(ofSize: 10)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.alignment = .right
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(pathLabel)
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -6),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -6),

            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(app: AppItem, isRunning: Bool, missing: Bool, selected: Bool) {
        let icon = NSWorkspace.shared.icon(forFile: app.path)
        icon.size = NSSize(width: 24, height: 24)
        iconView.image = icon

        nameLabel.stringValue = app.name
        pathLabel.stringValue = app.path

        if missing {
            statusLabel.stringValue = "已丢失"
            statusLabel.textColor = .systemRed
            nameLabel.textColor = .systemRed
        } else {
            statusLabel.stringValue = isRunning ? "运行中" : ""
            statusLabel.textColor = .systemGreen
            nameLabel.textColor = .labelColor
        }

        applyHighlight(selected)
    }
}
