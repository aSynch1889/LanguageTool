import SwiftUI
import AppKit

struct LocalizationMasterView: View {
    @StateObject var viewModel: LocalizationMasterViewModel

    init(viewModel: LocalizationMasterViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            LocalizationMasterTableView(
                items: viewModel.filteredItems,
                availableLanguages: viewModel.document.availableLanguages,
                sourceLanguage: viewModel.document.sourceLanguage,
                onItemUpdate: { viewModel.updateItem($0) }
            )
            Divider()
            footerBar
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if viewModel.document.isDirty {
                    Label("Unsaved changes", systemImage: "pencil.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label("Localization Master", systemImage: "tablecells")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(viewModel.document.filePath.isEmpty
                     ? "No file"
                     : URL(fileURLWithPath: viewModel.document.filePath).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                Toggle("Translate only checked rows".localized, isOn: $viewModel.translateSelectedOnly)
                Toggle("Skip existing".localized, isOn: $viewModel.skipExistingTranslations)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search".localized, text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.lastOperationSucceeded ? Color.secondary : Color.red)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var footerBar: some View {
        HStack(spacing: 10) {
            Menu("Add Language".localized) {
                if viewModel.addableLanguages.isEmpty {
                    Text("No languages to add".localized)
                } else {
                    ForEach(viewModel.addableLanguages) { language in
                        Button("\(language.localizedName) (\(language.code))") {
                            viewModel.addLanguage(language.code)
                        }
                    }
                }
            }

            Spacer()

            Button("Reload Source".localized) {
                Task { await viewModel.reload() }
            }
            .disabled(viewModel.isLoading)

            Button("Export".localized) {
                viewModel.exportCSV()
            }
            .disabled(viewModel.document.items.isEmpty)

            Button("Save".localized) {
                viewModel.save()
            }
            .disabled(viewModel.document.items.isEmpty || viewModel.isLoading)
            .keyboardShortcut("s", modifiers: .command)

            if viewModel.isLoading {
                Button("Cancel".localized) {
                    viewModel.cancelTranslation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button("Translate Now".localized) {
                    viewModel.translateNow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.document.items.isEmpty)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Table

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
        let tableView = NSTableView()

        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 8, height: 4)
        tableView.gridStyleMask = []
        tableView.headerView = NSTableHeaderView()

        let coordinator = context.coordinator
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        coordinator.tableView = tableView

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onItemUpdate = onItemUpdate

        let languagesChanged = coordinator.availableLanguages != availableLanguages
            || coordinator.sourceLanguage != sourceLanguage

        coordinator.items = items
        coordinator.availableLanguages = availableLanguages
        coordinator.sourceLanguage = sourceLanguage

        if languagesChanged {
            coordinator.setupColumnsIfNeeded(force: true)
        }

        // Avoid wiping first-responder / editing when only filter text changes.
        if !coordinator.isEditing {
            coordinator.tableView?.reloadData()
        } else {
            // Still refresh non-editing rows carefully.
            coordinator.tableView?.reloadData()
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        weak var tableView: NSTableView?
        var items: [TranslationItem] = []
        var availableLanguages: [String] = []
        var sourceLanguage: String = "en"
        var onItemUpdate: (TranslationItem) -> Void
        var isEditing = false

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
            checkbox.width = 56
            checkbox.minWidth = 56
            checkbox.maxWidth = 56
            tableView.addTableColumn(checkbox)

            let key = NSTableColumn(identifier: .init("key"))
            key.title = "Key"
            key.width = 220
            key.minWidth = 140
            tableView.addTableColumn(key)

            // Source language first (read-only styling in cell).
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
                column.width = 180
                column.minWidth = 120
                tableView.addTableColumn(column)
            }

            let comment = NSTableColumn(identifier: .init("comment"))
            comment.title = "Comment"
            comment.width = 160
            comment.minWidth = 100
            tableView.addTableColumn(comment)

            configuredLanguages = availableLanguages
            configuredSource = sourceLanguage
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < items.count, let tableColumn else { return nil }
            let item = items[row]
            let id = tableColumn.identifier.rawValue

            switch id {
            case "checkbox":
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
                return button

            case "key":
                let cellId = NSUserInterfaceItemIdentifier("KeyCell")
                let field: NSTextField
                if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTextField {
                    field = reused
                } else {
                    field = NSTextField(labelWithString: "")
                    field.identifier = cellId
                    field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                    field.lineBreakMode = .byTruncatingMiddle
                }
                field.stringValue = item.key
                field.toolTip = item.key
                return field

            case "comment":
                return makeEditableField(
                    tableView: tableView,
                    reuseId: "CommentCell",
                    value: item.comment,
                    row: row,
                    languageIndex: -1,
                    isSource: false
                )

            default:
                let isSource = id == sourceLanguage
                let value = item.translations[id] ?? ""
                let languageIndex = availableLanguages.firstIndex(of: id) ?? 0
                return makeEditableField(
                    tableView: tableView,
                    reuseId: "LangCell-\(id)",
                    value: value,
                    row: row,
                    languageIndex: languageIndex,
                    isSource: isSource,
                    languageCode: id
                )
            }
        }

        private func makeEditableField(
            tableView: NSTableView,
            reuseId: String,
            value: String,
            row: Int,
            languageIndex: Int,
            isSource: Bool,
            languageCode: String? = nil
        ) -> NSTextField {
            let cellId = NSUserInterfaceItemIdentifier(reuseId)
            let field: NSTextField
            if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTextField {
                field = reused
            } else {
                field = NSTextField(string: "")
                field.identifier = cellId
                field.isBordered = true
                field.isBezeled = true
                field.bezelStyle = .roundedBezel
                field.drawsBackground = true
                field.font = .systemFont(ofSize: 12)
                field.maximumNumberOfLines = 3
                field.cell?.wraps = true
                field.cell?.isScrollable = false
                field.delegate = self
                field.target = self
                field.action = #selector(textFieldCommitted(_:))
            }

            field.stringValue = value
            field.isEditable = !isSource
            field.isSelectable = true
            field.backgroundColor = isSource
                ? NSColor.controlBackgroundColor.withAlphaComponent(0.55)
                : (value.isEmpty ? NSColor.systemOrange.withAlphaComponent(0.08) : NSColor.textBackgroundColor)
            field.textColor = isSource ? .secondaryLabelColor : .labelColor
            field.tag = row
            field.toolTip = languageCode
            // Encode language index in identifier for commit handler when needed.
            if let languageCode {
                field.identifier = NSUserInterfaceItemIdentifier("LangCell-\(languageCode)")
            }
            return field
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            40
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

            if id == "CommentCell" || id.hasPrefix("comment") {
                updated.comment = field.stringValue
            } else if id.hasPrefix("LangCell-") {
                let code = String(id.dropFirst("LangCell-".count))
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

#if DEBUG
struct LocalizationMasterView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationMasterView(viewModel: LocalizationMasterViewModel())
    }
}
#endif
