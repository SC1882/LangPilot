import AppKit
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let monitor: InputMonitor
    private let spellingPopup = NSPopUpButton()
    private let durationPopup = NSPopUpButton()
    private let soundCheckbox = NSButton(checkboxWithTitle: "Play sound when the layout changes", target: nil, action: nil)
    private let launchCheckbox = NSButton(checkboxWithTitle: "Launch LangPilot at login", target: nil, action: nil)
    private let learnedCount = NSTextField(labelWithString: "")
    private let exclusionsTable = NSTableView()
    private var exclusions: [String] = []

    init(monitor: InputMonitor) {
        self.monitor = monitor
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "LangPilot Settings"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        loadValues()
    }

    required init?(coder: NSCoder) { nil }

    private func buildUI() {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab(title: "General", symbol: "gearshape", view: generalView()))
        tabs.addTabViewItem(tab(title: "Spelling", symbol: "textformat.abc", view: spellingView()))
        tabs.addTabViewItem(tab(title: "Learning", symbol: "brain.head.profile", view: learningView()))
        tabs.addTabViewItem(tab(title: "Privacy", symbol: "hand.raised", view: privacyView()))
        window?.contentViewController = tabs
    }

    private func tab(title: String, symbol: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: NSViewController())
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        item.viewController?.view = view
        return item
    }

    private func page(_ title: String, subtitle: String, controls: [NSView]) -> NSView {
        let root = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 28)
        ])
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        stack.addArrangedSubview(heading)
        let detail = NSTextField(wrappingLabelWithString: subtitle)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 2
        detail.widthAnchor.constraint(equalToConstant: 530).isActive = true
        stack.addArrangedSubview(detail)
        stack.addArrangedSubview(separator())
        controls.forEach { stack.addArrangedSubview($0) }
        return root
    }

    private func generalView() -> NSView {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let identity = NSStackView()
        identity.orientation = .horizontal
        identity.spacing = 16
        identity.addArrangedSubview(icon)
        let text = NSTextField(wrappingLabelWithString: "LangPilot 2.0 Beta\nSmart typing across languages")
        text.font = .systemFont(ofSize: 16, weight: .medium)
        identity.addArrangedSubview(text)
        let save = NSButton(title: "Save settings", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        return page("General", subtitle: "Choose how LangPilot behaves when you sign in and switch keyboard layouts.",
                    controls: [identity, soundCheckbox, launchCheckbox, save])
    }

    private func spellingView() -> NSView {
        spellingPopup.addItems(withTitles: ["Suggest corrections", "Correct obvious mistakes", "Spelling off"])
        durationPopup.addItems(withTitles: ["4 seconds", "8 seconds", "15 seconds", "Until dismissed"])
        return page("Spelling", subtitle: "Spelling is checked locally with the dictionaries installed on your Mac.",
                    controls: [row("Correction mode", spellingPopup),
                               row("Show suggestions for", durationPopup),
                               note("Tab accepts a suggestion. Esc dismisses it. LangPilot never sends text to a server.")])
    }

    private func learningView() -> NSView {
        let viewButton = NSButton(title: "View learned word pairs", target: self, action: #selector(viewLearning))
        let reset = NSButton(title: "Reset all learning…", target: self, action: #selector(resetLearning))
        reset.contentTintColor = .systemRed
        return page("Learning", subtitle: "Manual corrections and undo actions help LangPilot adapt to your vocabulary.",
                    controls: [learnedCount, viewButton, reset])
    }

    private func privacyView() -> NSView {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.title = "Applications where LangPilot is disabled"
        exclusionsTable.addTableColumn(column)
        exclusionsTable.headerView = nil
        exclusionsTable.delegate = self
        exclusionsTable.dataSource = self
        exclusionsTable.rowHeight = 30
        let scroll = NSScrollView()
        scroll.documentView = exclusionsTable
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.widthAnchor.constraint(equalToConstant: 530).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 190).isActive = true
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.addArrangedSubview(NSButton(title: "+ Add application", target: self, action: #selector(addApplication)))
        buttons.addArrangedSubview(NSButton(title: "− Remove", target: self, action: #selector(removeApplication)))
        return page("Privacy", subtitle: "Secure password fields are always ignored. Add any other application you do not want LangPilot to monitor.",
                    controls: [scroll, buttons, note("All processing and learned data stay on this Mac.")])
    }

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 14
        let text = NSTextField(labelWithString: label)
        text.widthAnchor.constraint(equalToConstant: 170).isActive = true
        row.addArrangedSubview(text)
        row.addArrangedSubview(control)
        return row
    }

    private func note(_ value: String) -> NSTextField {
        let text = NSTextField(wrappingLabelWithString: value)
        text.textColor = .secondaryLabelColor
        text.font = .systemFont(ofSize: 12)
        text.widthAnchor.constraint(equalToConstant: 530).isActive = true
        return text
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 530).isActive = true
        return box
    }

    private func loadValues() {
        spellingPopup.selectItem(at: monitor.spellingMode == .suggest ? 0 : monitor.spellingMode == .automatic ? 1 : 2)
        let durations: [TimeInterval] = [4, 8, 15, 3600]
        durationPopup.selectItem(at: durations.enumerated().min(by: {
            abs($0.element - monitor.suggestionDuration) < abs($1.element - monitor.suggestionDuration)
        })?.offset ?? 1)
        soundCheckbox.state = monitor.soundEnabled ? .on : .off
        launchCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        exclusions = monitor.excludedBundleIDs
        learnedCount.stringValue = "\(monitor.learnedEntries().count) learned word pairs"
    }

    @objc private func save() {
        monitor.spellingMode = [.suggest, .automatic, .off][spellingPopup.indexOfSelectedItem]
        monitor.suggestionDuration = [4, 8, 15, 3600][durationPopup.indexOfSelectedItem]
        monitor.soundEnabled = soundCheckbox.state == .on
        monitor.excludedBundleIDs = exclusions
        do {
            if launchCheckbox.state == .on && SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            if launchCheckbox.state == .off && SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
        } catch { showAlert("Could not update Login Item", detail: error.localizedDescription) }
    }

    @objc private func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !exclusions.contains(id) { exclusions.append(id) }
        }
        exclusions.sort()
        exclusionsTable.reloadData()
        monitor.excludedBundleIDs = exclusions
    }

    @objc private func removeApplication() {
        guard exclusionsTable.selectedRow >= 0 else { return }
        exclusions.remove(at: exclusionsTable.selectedRow)
        exclusionsTable.reloadData()
        monitor.excludedBundleIDs = exclusions
    }

    func numberOfRows(in tableView: NSTableView) -> Int { exclusions.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = exclusions[row]
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: id)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    @objc private func viewLearning() {
        let entries = monitor.learnedEntries()
        showAlert("Learned word pairs", detail: entries.isEmpty ? "No custom pairs yet." : entries.joined(separator: "\n"))
    }

    @objc private func resetLearning() {
        let alert = NSAlert()
        alert.messageText = "Reset all learned words?"
        alert.informativeText = "This removes personal corrections and exceptions. It cannot be undone."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        monitor.resetLearning()
        learnedCount.stringValue = "0 learned word pairs"
    }

    private func showAlert(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}
