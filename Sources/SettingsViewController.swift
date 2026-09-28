import AppKit

/// 设置窗口：管理模式和每个模式里的应用
final class SettingsViewController: NSViewController,
                                    NSTableViewDataSource,
                                    NSTableViewDelegate {

    // MARK: - UI

    private let modeTable = NSTableView()
    private let appTable = NSTableView()
    private let nameField = NSTextField()
    private let iconField = NSTextField()
    private let removeModeButton = NSButton()
    private let addAppButton = NSButton()
    private let removeAppButton = NSButton()
    private let titleHint = NSTextField(labelWithString: "")
    private let savedLabel = NSTextField(labelWithString: "")
    private let emptyHint = NSTextField(wrappingLabelWithString: "这个模式还没有应用\n点下方「添加应用…」，或直接把 .app 拖进来")

    private var selectedModeID: UUID?
    /// 记住用户选中的是哪个应用（用 id，不依赖 NSInteger 行号），任何刷新后都按它恢复
    private var selectedAppID: UUID?
    private var configObserver: NSObjectProtocol?
    private var refreshTimer: Timer?
    private var lastAppSignature = ""

    private var selectedMode: LaunchMode? {
        guard let id = selectedModeID else { return nil }
        return ConfigStore.shared.mode(id: id)
    }

    // MARK: - 生命周期

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 780, height: 520))
        view = container

        // ---- 左：模式列表 ----
        setup(modeTable, rowHeight: 30)
        let modeScroll = scrollView(for: modeTable)

        let addMode = NSButton(title: "＋ 模式", target: self, action: #selector(addModeClicked(_:)))
        removeModeButton.title = "－ 模式"
        removeModeButton.target = self
        removeModeButton.action = #selector(removeModeClicked(_:))
        for b in [addMode, removeModeButton] { configure(button: b) }

        let modeRow = NSStackView(views: [addMode, removeModeButton])
        modeRow.orientation = .horizontal
        modeRow.spacing = 8
        modeRow.distribution = .fillEqually

        view.addSubview(modeScroll)
        view.addSubview(modeRow)

        // ---- 右：模式详情 ----
        let nameLabel = NSTextField(labelWithString: "名称")
        let iconLabel = NSTextField(labelWithString: "图标")
        for l in [nameLabel, iconLabel] { l.textColor = .secondaryLabelColor }

        configureEditable(nameField)
        nameField.target = self
        nameField.action = #selector(nameEdited(_:))

        configureEditable(iconField)
        iconField.target = self
        iconField.action = #selector(iconEdited(_:))

        savedLabel.font = .systemFont(ofSize: 11)
        savedLabel.textColor = .systemGreen
        savedLabel.alphaValue = 0

        let formRow = NSStackView(views: [nameLabel, nameField, iconLabel, iconField, savedLabel])
        formRow.orientation = .horizontal
        formRow.spacing = 8
        formRow.alignment = .centerY

        setup(appTable, rowHeight: 40)
        appTable.doubleAction = #selector(doubleClickedApp)
        appTable.target = self
        appTable.registerForDraggedTypes([.fileURL])
        let appScroll = scrollView(for: appTable)

        addAppButton.title = "添加应用…"
        addAppButton.target = self
        addAppButton.action = #selector(addAppsClicked(_:))
        removeAppButton.title = "移除"
        removeAppButton.target = self
        removeAppButton.action = #selector(removeAppClicked(_:))
        for b in [addAppButton, removeAppButton] { configure(button: b) }

        let revealButton = NSButton(title: "打开配置文件夹",
                                    target: self,
                                    action: #selector(revealConfig(_:)))
        configure(button: revealButton)
        let spacer = NSView()

        let actionRow = NSStackView(views: [addAppButton, removeAppButton, spacer, revealButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.alignment = .centerY

        titleHint.stringValue = "提示：也可以直接把 .app 拖进下面的列表里添加"
        titleHint.font = .systemFont(ofSize: 11)
        titleHint.textColor = .secondaryLabelColor

        emptyHint.alignment = .center
        emptyHint.font = .systemFont(ofSize: 12)
        emptyHint.textColor = .secondaryLabelColor

        view.addSubview(formRow)
        view.addSubview(appScroll)
        view.addSubview(actionRow)
        view.addSubview(titleHint)
        view.addSubview(emptyHint)

        // ---- 布局 ----
        func lead(_ v: NSView) { v.translatesAutoresizingMaskIntoConstraints = false }
        [modeScroll, modeRow, formRow, appScroll, actionRow, titleHint, emptyHint].forEach(lead)

        NSLayoutConstraint.activate([
            modeScroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            modeScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            modeScroll.widthAnchor.constraint(equalToConstant: 200),

            modeRow.topAnchor.constraint(equalTo: modeScroll.bottomAnchor, constant: 10),
            modeRow.leadingAnchor.constraint(equalTo: modeScroll.leadingAnchor),
            modeRow.widthAnchor.constraint(equalTo: modeScroll.widthAnchor),
            modeRow.heightAnchor.constraint(equalToConstant: 28),
            view.bottomAnchor.constraint(equalTo: modeRow.bottomAnchor, constant: 16),

            formRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            formRow.leadingAnchor.constraint(equalTo: modeScroll.trailingAnchor, constant: 16),
            formRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            appScroll.topAnchor.constraint(equalTo: formRow.bottomAnchor, constant: 12),
            appScroll.leadingAnchor.constraint(equalTo: formRow.leadingAnchor),
            appScroll.trailingAnchor.constraint(equalTo: formRow.trailingAnchor),

            actionRow.topAnchor.constraint(equalTo: appScroll.bottomAnchor, constant: 10),
            actionRow.leadingAnchor.constraint(equalTo: formRow.leadingAnchor),
            actionRow.trailingAnchor.constraint(equalTo: formRow.trailingAnchor),
            actionRow.heightAnchor.constraint(equalToConstant: 28),

            titleHint.topAnchor.constraint(equalTo: actionRow.bottomAnchor, constant: 10),
            titleHint.leadingAnchor.constraint(equalTo: formRow.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: titleHint.bottomAnchor, constant: 14),

            emptyHint.centerXAnchor.constraint(equalTo: appScroll.centerXAnchor),
            emptyHint.centerYAnchor.constraint(equalTo: appScroll.centerYAnchor),
            emptyHint.widthAnchor.constraint(lessThanOrEqualToConstant: 340)
        ])

        NSLayoutConstraint.activate([
            nameLabel.widthAnchor.constraint(equalToConstant: 32),
            iconLabel.widthAnchor.constraint(equalToConstant: 32),
            nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            iconField.widthAnchor.constraint(equalToConstant: 56)
        ])

        configObserver = NotificationCenter.default.addObserver(
            forName: .workModeConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.reloadAllKeepingSelection()
            self.flashSaved()
        }

        // 输入框失焦时自动保存
        endEditObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self,
                  let field = note.object as? NSTextField,
                  field.window === self.view.window else { return }
            if field === self.nameField {
                self.commitName()
            } else if field === self.iconField {
                self.commitIcon()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if selectedModeID == nil {
            selectedModeID = ConfigStore.shared.config.modes.first?.id
        }
        reloadDetail()
        modeTable.reloadData()
        restoreModeSelection()

        lastAppSignature = appTableSignature()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.view.window != nil else { return }
            // 用户正在输入时不刷新，避免打断编辑
            if self.view.window?.firstResponder is NSTextView { return }
            let signature = self.appTableSignature()
            guard signature != self.lastAppSignature else { return }
            self.lastAppSignature = signature
            self.refreshVisibleAppRows()
        }
    }

    deinit {
        if let observer = configObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = endEditObserver { NotificationCenter.default.removeObserver(observer) }
        refreshTimer?.invalidate()
    }

    // MARK: - UI 小工具

    private func configure(button: NSButton) {
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureEditable(_ field: NSTextField) {
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.isEditable = true
        field.isSelectable = true
        field.font = .systemFont(ofSize: 13)
        field.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setup(_ table: NSTableView, rowHeight: CGFloat) {
        table.rowHeight = rowHeight
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.style = .inset
        // 关掉系统选中高亮：它会在窗口失焦/刷新时自己消失，改成单元格自己画
        table.selectionHighlightStyle = .none
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        column.resizingMask = .autoresizingMask
        column.width = 300
        table.addTableColumn(column)
    }

    private func scrollView(for table: NSTableView) -> NSScrollView {
        let scroll = NSScrollView(frame: .zero)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        return scroll
    }

    // MARK: - 数据刷新

    func currentSelection() -> UUID? {
        if let id = selectedModeID { return id }
        return ConfigStore.shared.config.modes.first?.id
    }

    func select(modeID: UUID?) {
        if let id = modeID { selectedModeID = id }
        guard isViewLoaded else { return }
        reloadDetail()
        restoreModeSelection()
    }

    private func reloadAllKeepingSelection() {
        let appID = selectedAppID ?? currentAppSelectionID()
        modeTable.reloadData()
        appTable.reloadData()
        restoreModeSelection()
        restoreAppSelection(id: appID)
        lastAppSignature = appTableSignature()
    }

    private func reloadAppTableKeepingSelection() {
        let appID = selectedAppID ?? currentAppSelectionID()
        appTable.reloadData()
        restoreAppSelection(id: appID)
        lastAppSignature = appTableSignature()
    }

    /// 只就地更新可见单元格，不触发 reloadData，所以绝不会冲掉行选中
    private func refreshVisibleAppRows() {
        guard let mode = selectedMode else { return }
        for (index, app) in mode.apps.enumerated() {
            guard let cell = appTable.view(atColumn: 0, row: index, makeIfNecessary: false) as? AppCellView else { continue }
            cell.configure(app: app,
                           isRunning: Launcher.isRunning(app),
                           missing: !FileManager.default.fileExists(atPath: app.path),
                           selected: app.id == selectedAppID)
        }
        if appTable.selectedRow < 0, let id = selectedAppID {
            restoreAppSelection(id: id)
        }
    }

    private func refreshVisibleModeRows() {
        for (index, mode) in ConfigStore.shared.config.modes.enumerated() {
            guard let cell = modeTable.view(atColumn: 0, row: index, makeIfNecessary: false) as? ModeCellView else { continue }
            cell.configure(mode: mode, selected: mode.id == selectedModeID)
        }
        if modeTable.selectedRow < 0, let id = selectedModeID {
            restoreModeSelection()
            _ = id
        }
    }

    /// 应用表的状态签名：内容、运行状态、丢失状态有一个变化才真正刷新
    private func appTableSignature() -> String {
        guard let mode = selectedMode else { return "" }
        return mode.apps.map { app in
            let running = Launcher.isRunning(app) ? "1" : "0"
            let exists = FileManager.default.fileExists(atPath: app.path) ? "1" : "0"
            return "\(app.id):\(running)\(exists)"
        }.joined(separator: "|")
    }

    private func currentAppSelectionID() -> UUID? {
        guard let mode = selectedMode,
              appTable.selectedRow >= 0,
              appTable.selectedRow < mode.apps.count else { return nil }
        return mode.apps[appTable.selectedRow].id
    }

    private func restoreAppSelection(id: UUID?) {
        guard let id = id, let mode = selectedMode,
              let idx = mode.apps.firstIndex(where: { $0.id == id }) else { return }
        appTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
    }

    /// 「✓ 已保存」短暂提示，任何配置保存成功都会亮一下
    private func flashSaved() {
        guard view.window != nil else { return }
        savedLabel.stringValue = "✓ 已保存"
        savedLabel.alphaValue = 1
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(hideSaved),
                                               object: nil)
        perform(#selector(hideSaved), with: nil, afterDelay: 1.6)
    }

    @objc private func hideSaved() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            savedLabel.animator().alphaValue = 0
        }
    }

    private func restoreModeSelection() {
        guard let id = selectedModeID,
              let idx = ConfigStore.shared.config.modes.firstIndex(where: { $0.id == id }) else { return }
        modeTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
    }

    private func restoreAppSelection() {
        guard appTable.selectedRow >= 0 else { return }
        let row = min(appTable.selectedRow, max(0, appTable.numberOfRows - 1))
        if appTable.numberOfRows > 0 {
            appTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    private func reloadDetail() {
        guard isViewLoaded else { return }
        let hasMode = selectedMode != nil
        let mode = selectedMode

        nameField.stringValue = mode?.name ?? ""
        iconField.stringValue = mode?.icon ?? ""

        for control in [nameField, iconField, removeModeButton, addAppButton, removeAppButton] {
            control.isEnabled = hasMode
        }

        // 没有任何应用时给个明确指引
        emptyHint.isHidden = !(mode?.apps.isEmpty ?? true)

        appTable.reloadData()
        lastAppSignature = appTableSignature()
    }

    // MARK: - 表格数据源

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === modeTable {
            return ConfigStore.shared.config.modes.count
        }
        return selectedMode?.apps.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        if tableView === modeTable {
            let mode = ConfigStore.shared.config.modes[row]
            let id = NSUserInterfaceItemIdentifier("ModeCell")
            let cell = (tableView.makeView(withIdentifier: id, owner: self) as? ModeCellView) ?? {
                let cell = ModeCellView()
                cell.identifier = id
                return cell
            }()
            cell.configure(mode: mode, selected: mode.id == selectedModeID)
            return cell
        }

        guard let mode = selectedMode, row < mode.apps.count else { return nil }
        let app = mode.apps[row]
        let id = NSUserInterfaceItemIdentifier("AppCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? AppCellView) ?? {
            let cell = AppCellView()
            cell.identifier = id
            return cell
        }()
        cell.configure(app: app,
                       isRunning: Launcher.isRunning(app),
                       missing: !FileManager.default.fileExists(atPath: app.path),
                       selected: app.id == selectedAppID)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }

        if table === modeTable {
            let row = modeTable.selectedRow
            guard row >= 0, row < ConfigStore.shared.config.modes.count else {
                selectedModeID = nil
                reloadDetail()
                return
            }
            selectedModeID = ConfigStore.shared.config.modes[row].id
            selectedAppID = nil          // 换了模式，应用选中重置
            reloadDetail()
            refreshVisibleModeRows()
            return
        }

        if table === appTable {
            selectedAppID = currentAppSelectionID()
            // 选中变化后立刻重画高亮（不等定时器）
            refreshVisibleAppRows()
        }
    }

    // MARK: - 拖放 .app 添加

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard tableView === appTable, selectedModeID != nil else { return [] }
        return .copy
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        guard tableView === appTable, let modeID = selectedModeID else { return false }
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        let added = ConfigStore.shared.addApps(urls, to: modeID)
        reloadAppTableKeepingSelection()
        modeTable.reloadData()
        return added > 0
    }

    // MARK: - 动作

    @objc private func addModeClicked(_ sender: Any?) {
        let mode = ConfigStore.shared.addMode()
        modeTable.reloadData()
        selectedModeID = mode.id
        reloadDetail()
        restoreModeSelection()
        view.window?.makeFirstResponder(nameField)
        nameField.selectText(nil)
    }

    @objc private func removeModeClicked(_ sender: Any?) {
        guard let id = selectedModeID,
              let mode = ConfigStore.shared.mode(id: id) else { return }

        let alert = NSAlert()
        alert.messageText = "删除模式「\(mode.name)」？"
        alert.informativeText = "这个模式里的 \(mode.apps.count) 个应用配置会被移除，应用本身不会被删除。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            guard let self = self else { return }
            ConfigStore.shared.removeMode(id)
            self.selectedModeID = ConfigStore.shared.config.modes.first?.id
            self.reloadDetail()
            self.modeTable.reloadData()
            self.restoreModeSelection()
        }
    }

    @objc private func nameEdited(_ sender: NSTextField) {
        commitName()
    }

    @objc private func iconEdited(_ sender: NSTextField) {
        commitIcon()
    }

    /// 失焦时也提交（回车走 action，点击别处走这里的通知）
    // 用通知而不是 delegate：NSTextFieldDelegate 在新 SDK 里是 MainActor 隔离的
    private var endEditObserver: NSObjectProtocol?

    /// 名称提交：空值自动还原为原名
    private func commitName() {
        guard let id = selectedModeID, let mode = selectedMode else { return }
        let value = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            nameField.stringValue = mode.name
            return
        }
        guard value != mode.name else { return }
        ConfigStore.shared.updateMode(id, name: value)
        modeTable.reloadData()
        restoreModeSelection()
    }

    /// 图标提交：最多取 2 个字符，空值还原为当前图标
    private func commitIcon() {
        guard let id = selectedModeID, let mode = selectedMode else { return }
        let raw = iconField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = raw.isEmpty ? mode.icon : String(raw.prefix(2))
        guard icon != mode.icon else {
            iconField.stringValue = mode.icon
            return
        }
        iconField.stringValue = icon
        ConfigStore.shared.updateMode(id, icon: icon)
        modeTable.reloadData()
        restoreModeSelection()
    }

    @objc private func addAppsClicked(_ sender: Any?) {
        guard let modeID = selectedModeID, let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "添加"
        panel.message = "按住 ⌘ 可以一次选择多个应用"

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self = self else { return }
            let added = ConfigStore.shared.addApps(panel.urls, to: modeID)
            if added == 0 {
                let alert = NSAlert()
                alert.messageText = "没有添加任何应用"
                alert.informativeText = "可能这些应用已经在这个模式里了。"
                alert.runModal()
            }
            self.reloadAppTableKeepingSelection()
            self.modeTable.reloadData()
        }
    }

    @objc private func removeAppClicked(_ sender: Any?) {
        guard let modeID = selectedModeID,
              let mode = selectedMode else { return }
        let targetID = selectedAppID ?? currentAppSelectionID()
        guard let id = targetID, mode.apps.contains(where: { $0.id == id }) else { return }
        ConfigStore.shared.removeApp(modeID: modeID, appID: id)
        selectedAppID = nil
        reloadAppTableKeepingSelection()
        modeTable.reloadData()
    }

    @objc private func doubleClickedApp(_ sender: Any?) {
        guard appTable.clickedRow >= 0,
              let mode = selectedMode,
              appTable.clickedRow < mode.apps.count else { return }
        let app = mode.apps[appTable.clickedRow]
        selectedAppID = app.id
        Launcher.launch(app: app)
        refreshVisibleAppRows()
    }

    @objc private func revealConfig(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.fileURL])
    }
}
