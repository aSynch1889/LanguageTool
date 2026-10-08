import SwiftUI
import AppKit

/// AppKit-backed localization grid with cell reuse and source/target styling.
struct LocalizationMasterTableView: NSViewRepresentable {
    let items: [TranslationItem]
    let availableLanguages: [String]
    let sourceLanguage: String
    let onItemUpdate: (TranslationItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onItemUpdate: onItemUpdate)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = MasterTableView()

        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 10, height: 6)
        tableView.gridStyleMask = []
        tableView.headerView = NSTableHeaderView()
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = .clear

        let coordinator = context.coordinator
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        coordinator.tableView = tableView

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onItemUpdate = onItemUpdate

        let languagesChanged = coordinator.availableLanguages != availableLanguages
            || coordinator.sourceLanguage != sourceLanguage
        let itemsIdentityChanged = coordinator.items.map(\.key) != items.map(\.key)
        let contentChanged = coordinator.items != items

        coordinator.availableLanguages = availableLanguages
        coordinator.sourceLanguage = sourceLanguage

        if languagesChanged {
            coordinator.items = items
            coordinator.setupColumnsIfNeeded(force: true)
            coordinator.tableView?.reloadData()
            return
        }

        // Preserve first responder while user is editing a cell.
        if coordinator.isEditing {
            coordinator.items = items
            return
        }

        if itemsIdentityChanged || contentChanged {
            let selectedRow = coordinator.tableView?.selectedRow ?? -1
            let clip = scrollView.contentView.bounds.origin
            coordinator.items = items
            coordinator.tableView?.reloadData()
            if selectedRow >= 0, selectedRow < items.count {
                coordinator.tableView?.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            }
            scrollView.contentView.scroll(to: clip)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        } else {
            coordinator.items = items
        }
    }

    final class MasterTableView: NSTableView {
        override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
            // Allow clicking into text fields without requiring row selection first.
            if responder is NSTextField || responder is NSButton {
                return true
            }
            return super.validateProposedFirstResponder(responder, for: event)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        weak var tableView: NSTableView?
        var items: [TranslationItem] = []
        var availableLanguages: [String] = []
        var sourceLanguage: String = "en"
        var onItemUpdate: (TranslationItem) -> Void
        private(set) var isEditing = false

        private var configuredLanguages: [String] = []
        private var configuredSource = ""

        init(onItemUpdate: @escaping (TranslationItem) -> Void) {
            self.onItemUpdate = onItemUpdate
        }

        func setupColumnsIfNeeded(force: Bool = false) {
            guard let tableView else { return }
            if !force,
               configuredLanguages == availableLanguages,
               configuredSource == sourceLanguage,
               !tableView.tableColumns.isEmpty {
                return
            }

            tableView.tableColumns.forEach { tableView.removeTableColumn($0) }

            let checkbox = NSTableColumn(identifier: .init("checkbox"))
            checkbox.title = "Batch"
            checkbox.width = 58
            checkbox.minWidth = 58
            checkbox.maxWidth = 58
            tableView.addTableColumn(checkbox)

            let key = NSTableColumn(identifier: .init("key"))
            key.title = "Key"
            key.width = 240
            key.minWidth = 160
            tableView.addTableColumn(key)

            let ordered = availableLanguages.sorted { lhs, rhs in
                if lhs == sourceLanguage { return true }
                if rhs == sourceLanguage { return false }
                return lhs < rhs
            }

            for code in ordered {
                let column = NSTableColumn(identifier: .init(code))
                if code == sourceLanguage {
                    column.title = "\(code) · Source"
                } else if let language = Language.supportedLanguages.first(where: { $0.code == code }) {
                    column.title = "\(code) · \(language.localizedName)"
                } else {
                    column.title = code
                }
                column.width = 200
                column.minWidth = 140
                tableView.addTableColumn(column)
            }

            let comment = NSTableColumn(identifier: .init("comment"))
            comment.title = "Comment"
            comment.width = 180
            comment.minWidth = 120
            tableView.addTableColumn(comment)

            configuredLanguages = availableLanguages
            configuredSource = sourceLanguage
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            items.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard row < items.count else { return 44 }
            let item = items[row]
            let longest = item.translations.values.map(\.count).max() ?? 0
            if longest > 80 { return 64 }
            if longest > 40 { return 52 }
            return 44
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < items.count, let tableColumn else { return nil }
            let item = items[row]
            let id = tableColumn.identifier.rawValue

            switch id {
            case "checkbox":
                return checkboxCell(tableView: tableView, item: item, row: row)
            case "key":
                return keyCell(tableView: tableView, item: item)
            case "comment":
                return textCell(
                    tableView: tableView,
                    reuseId: "CommentCell",
                    value: item.comment,
                    row: row,
                    isSource: false,
                    languageCode: nil,
                    isComment: true
                )
            default:
                return textCell(
                    tableView: tableView,
                    reuseId: "LangCell-\(id)",
                    value: item.translations[id] ?? "",
                    row: row,
                    isSource: id == sourceLanguage,
                    languageCode: id,
                    isComment: false
                )
            }
        }

        private func checkboxCell(tableView: NSTableView, item: TranslationItem, row: Int) -> NSButton {
            let cellId = NSUserInterfaceItemIdentifier("CheckboxCell")
            let button: NSButton
            if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSButton {
                button = reused
            } else {
                button = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged(_:)))
                button.identifier = cellId
            }
            button.state = item.isSelected ? .on : .off
            button.tag = row
            button.toolTip = "Include in batch translate"
            return button
        }

        private func keyCell(tableView: NSTableView, item: TranslationItem) -> NSTextField {
            let cellId = NSUserInterfaceItemIdentifier("KeyCell")
            let field: NSTextField
            if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTextField {
                field = reused
            } else {
                field = NSTextField(labelWithString: "")
                field.identifier = cellId
                field.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
                field.lineBreakMode = .byTruncatingMiddle
                field.textColor = .labelColor
            }
            field.stringValue = item.key
            field.toolTip = item.key
            return field
        }

        private func textCell(
            tableView: NSTableView,
            reuseId: String,
            value: String,
            row: Int,
            isSource: Bool,
            languageCode: String?,
            isComment: Bool
        ) -> NSTextField {
            let cellId = NSUserInterfaceItemIdentifier(reuseId)
            let field: NSTextField
            if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTextField {
                field = reused
            } else {
                field = NSTextField(string: "")
                field.identifier = cellId
                field.isBordered = false
                field.isBezeled = false
                field.drawsBackground = true
                field.font = .systemFont(ofSize: 12)
                field.maximumNumberOfLines = 0
                field.lineBreakMode = .byWordWrapping
                field.cell?.wraps = true
                field.cell?.isScrollable = false
                field.focusRingType = .exterior
                field.delegate = self
                field.target = self
                field.action = #selector(textFieldCommitted(_:))
            }

            field.stringValue = value
            field.isEditable = !isSource
            field.isSelectable = true
            field.tag = row

            if isSource {
                field.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
                field.textColor = .secondaryLabelColor
            } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                field.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.10)
                field.textColor = .labelColor
                field.placeholderString = isComment ? "Comment" : "Missing translation"
            } else {
                field.backgroundColor = NSColor.textBackgroundColor
                field.textColor = .labelColor
                field.placeholderString = nil
            }

            if let languageCode {
                field.identifier = NSUserInterfaceItemIdentifier("LangCell-\(languageCode)")
                field.toolTip = languageCode
            } else {
                field.identifier = NSUserInterfaceItemIdentifier("CommentCell")
                field.toolTip = "Comment"
            }
            return field
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            if let field = obj.object as? NSTextField {
                applyTextField(field)
            }
        }

        @objc private func textFieldCommitted(_ sender: NSTextField) {
            applyTextField(sender)
        }

        private func applyTextField(_ field: NSTextField) {
            let row = field.tag
            guard row >= 0, row < items.count else { return }
            var updated = items[row]
            let id = field.identifier?.rawValue ?? ""

            if id == "CommentCell" {
                guard updated.comment != field.stringValue else { return }
                updated.comment = field.stringValue
            } else if id.hasPrefix("LangCell-") {
                let code = String(id.dropFirst("LangCell-".count))
                guard updated.translations[code] != field.stringValue else { return }
                updated.translations[code] = field.stringValue
            } else {
                return
            }

            items[row] = updated
            onItemUpdate(updated)
        }

        @objc func checkboxChanged(_ sender: NSButton) {
            let row = sender.tag
            guard row < items.count else { return }
            var updated = items[row]
            updated.isSelected = sender.state == .on
            items[row] = updated
            onItemUpdate(updated)
        }
    }
}
