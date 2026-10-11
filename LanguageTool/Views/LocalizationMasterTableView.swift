import SwiftUI
import AppKit

/// AppKit-backed localization grid with cell reuse and source/target styling.
struct LocalizationMasterTableView: NSViewRepresentable {
    let items: [TranslationItem]
    let availableLanguages: [String]
    let sourceLanguage: String
    let batchHeaderState: NSControl.StateValue
    let onToggleBatchHeader: () -> Void
    let onItemUpdate: (TranslationItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onItemUpdate: onItemUpdate, onToggleBatchHeader: onToggleBatchHeader)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = MasterTableView()

        // Plain + no alternating rows avoids "white box on gray" patchwork.
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = NSColor.textBackgroundColor
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.gridColor = NSColor.separatorColor.withAlphaComponent(0.12)
        // Use a real height — `frame: .zero` collapses the header and it never recovers.
        let headerView = MasterTableHeaderView(frame: NSRect(x: 0, y: 0, width: 500, height: 28))
        tableView.headerView = headerView
        tableView.selectionHighlightStyle = .regular

        let coordinator = context.coordinator
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        coordinator.tableView = tableView
        headerView.onBatchToggle = { [weak coordinator] in
            coordinator?.onToggleBatchHeader()
        }

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
        coordinator.onToggleBatchHeader = onToggleBatchHeader
        coordinator.batchHeaderState = batchHeaderState

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
            coordinator.syncBatchHeader()
            return
        }

        if coordinator.isEditing {
            coordinator.items = items
            coordinator.syncBatchHeader()
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
        coordinator.syncBatchHeader()
    }

    /// Checkbox + “Batch” title in the table header (drawing only; clicks handled by header view).
    final class BatchSelectHeaderCell: NSTableHeaderCell {
        var checkboxState: NSControl.StateValue = .off

        override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
            // Keep default header chrome, then paint checkbox + title.
            let saved = stringValue
            stringValue = ""
            super.draw(withFrame: cellFrame, in: controlView)
            stringValue = saved
            drawBatchContents(in: cellFrame)
        }

        private func drawBatchContents(in cellFrame: NSRect) {
            let box: CGFloat = 15
            let checkRect = NSRect(
                x: cellFrame.minX + 14,
                y: floor(cellFrame.midY - box / 2),
                width: box,
                height: box
            )
            // Match NSButton checkbox: green fill + white glyph (not a solid green block).
            let symbolName: String
            let colorConfig: NSImage.SymbolConfiguration
            switch checkboxState {
            case .on:
                symbolName = "checkmark.square.fill"
                colorConfig = NSImage.SymbolConfiguration(paletteColors: [ThemeAccent.brandNS, .white])
            case .mixed:
                symbolName = "minus.square.fill"
                colorConfig = NSImage.SymbolConfiguration(paletteColors: [ThemeAccent.brandNS, .white])
            default:
                symbolName = "square"
                colorConfig = NSImage.SymbolConfiguration(paletteColors: [ThemeAccent.brandNS])
            }
            let sizeConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
               let image = base.withSymbolConfiguration(sizeConfig)?.withSymbolConfiguration(colorConfig) {
                image.draw(
                    in: checkRect,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
            }

            let title = stringValue as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let titleSize = title.size(withAttributes: attrs)
            let titleOrigin = NSPoint(
                x: checkRect.maxX + 6,
                y: floor(cellFrame.midY - titleSize.height / 2)
            )
            title.draw(at: titleOrigin, withAttributes: attrs)
        }
    }

    /// `NSTableHeaderCell.trackMouse` is not reliably invoked; handle Batch clicks here.
    final class MasterTableHeaderView: NSTableHeaderView {
        var onBatchToggle: (() -> Void)?

        override init(frame frameRect: NSRect) {
            var frame = frameRect
            if frame.height < 1 { frame.size.height = 28 }
            if frame.width < 1 { frame.size.width = 500 }
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: max(bounds.height, 28))
        }

        override func mouseDown(with event: NSEvent) {
            guard let tableView else {
                super.mouseDown(with: event)
                return
            }
            let point = convert(event.locationInWindow, from: nil)
            let columnIndex = column(at: point)
            if columnIndex >= 0,
               columnIndex < tableView.tableColumns.count,
               tableView.tableColumns[columnIndex].identifier.rawValue == "checkbox" {
                onBatchToggle?()
                needsDisplay = true
                return
            }
            super.mouseDown(with: event)
        }
    }

    final class MasterTableView: NSTableView {
        override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
            if responder is NSTextField || responder is NSButton {
                return true
            }
            return super.validateProposedFirstResponder(responder, for: event)
        }
    }

    /// Soft brand-green selection instead of deep system-blue highlight.
    final class BrandTableRowView: NSTableRowView {
        override func drawSelection(in dirtyRect: NSRect) {
            guard selectionHighlightStyle != .none else { return }
            ThemeAccent.selectionFillNS.setFill()
            dirtyRect.intersection(bounds).fill()
        }

        /// Keep normal label colors (avoid white text on the light green fill).
        override var isEmphasized: Bool {
            get { false }
            set { }
        }
    }

    /// Vertically centers a single child inside the table cell bounds.
    final class CenteredCellView: NSTableCellView {
        private let hostedView: NSView

        init(
            identifier: NSUserInterfaceItemIdentifier,
            hostedView: NSView,
            leadingInset: CGFloat = 8,
            trailingInset: CGFloat = 8
        ) {
            self.hostedView = hostedView
            super.init(frame: .zero)
            self.identifier = identifier
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
                hostedView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingInset),
                hostedView.centerYAnchor.constraint(equalTo: centerYAnchor),
                hostedView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4),
                hostedView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        weak var tableView: NSTableView?
        var items: [TranslationItem] = []
        var availableLanguages: [String] = []
        var sourceLanguage: String = "en"
        var batchHeaderState: NSControl.StateValue = .off
        var onItemUpdate: (TranslationItem) -> Void
        var onToggleBatchHeader: () -> Void
        private(set) var isEditing = false

        private var configuredLanguages: [String] = []
        private var configuredSource = ""

        init(
            onItemUpdate: @escaping (TranslationItem) -> Void,
            onToggleBatchHeader: @escaping () -> Void
        ) {
            self.onItemUpdate = onItemUpdate
            self.onToggleBatchHeader = onToggleBatchHeader
        }

        func syncBatchHeader() {
            if let header = tableView?.headerView as? MasterTableHeaderView {
                header.onBatchToggle = { [weak self] in
                    self?.onToggleBatchHeader()
                }
                if header.frame.height < 1 {
                    var frame = header.frame
                    frame.size.height = 28
                    header.frame = frame
                }
            } else if let tableView {
                // Recover if header was dropped during layout.
                let header = MasterTableHeaderView(frame: NSRect(x: 0, y: 0, width: max(tableView.bounds.width, 500), height: 28))
                header.onBatchToggle = { [weak self] in
                    self?.onToggleBatchHeader()
                }
                tableView.headerView = header
            }
            guard let column = tableView?.tableColumns.first(where: { $0.identifier.rawValue == "checkbox" }),
                  let cell = column.headerCell as? BatchSelectHeaderCell else { return }
            cell.checkboxState = batchHeaderState
            tableView?.headerView?.needsDisplay = true
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
            let header = BatchSelectHeaderCell(textCell: "Batch".localized)
            header.checkboxState = batchHeaderState
            checkbox.headerCell = header
            checkbox.width = 88
            checkbox.minWidth = 88
            checkbox.maxWidth = 100
            tableView.addTableColumn(checkbox)

            let key = NSTableColumn(identifier: .init("key"))
            key.title = "Key".localized
            key.width = 220
            key.minWidth = 140
            tableView.addTableColumn(key)

            let ordered = availableLanguages.sorted { lhs, rhs in
                if lhs == sourceLanguage { return true }
                if rhs == sourceLanguage { return false }
                return lhs < rhs
            }

            for code in ordered {
                let column = NSTableColumn(identifier: .init(code))
                if code == sourceLanguage {
                    column.title = "%@ · Source".localizedFormat(code)
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
            comment.title = "Comment".localized
            comment.width = 160
            comment.minWidth = 100
            tableView.addTableColumn(comment)

            configuredLanguages = availableLanguages
            configuredSource = sourceLanguage
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            items.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            36
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let id = NSUserInterfaceItemIdentifier("BrandRow")
            if let rowView = tableView.makeView(withIdentifier: id, owner: self) as? BrandTableRowView {
                return rowView
            }
            let rowView = BrandTableRowView()
            rowView.identifier = id
            return rowView
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

        private func checkboxCell(tableView: NSTableView, item: TranslationItem, row: Int) -> NSView {
            let wrapId = NSUserInterfaceItemIdentifier("CheckboxWrap")
            if let wrap = tableView.makeView(withIdentifier: wrapId, owner: self) as? CenteredCellView,
               let button = wrap.subviews.first as? NSButton {
                applyBrandTint(to: button)
                button.state = item.isSelected ? .on : .off
                button.tag = row
                return wrap
            }

            let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged(_:)))
            applyBrandTint(to: button)
            button.state = item.isSelected ? .on : .off
            button.tag = row
            button.toolTip = "Include in batch translate"
            button.setButtonType(.switch)
            return CenteredCellView(
                identifier: wrapId,
                hostedView: button,
                leadingInset: 16,
                trailingInset: 8
            )
        }

        private func applyBrandTint(to button: NSButton) {
            button.contentTintColor = ThemeAccent.brandNS
        }

        private func keyCell(tableView: NSTableView, item: TranslationItem) -> NSView {
            let wrapId = NSUserInterfaceItemIdentifier("KeyWrap")
            if let wrap = tableView.makeView(withIdentifier: wrapId, owner: self) as? CenteredCellView,
               let field = wrap.subviews.first as? NSTextField {
                field.stringValue = item.key
                field.toolTip = item.key
                return wrap
            }

            let field = NSTextField(labelWithString: item.key)
            field.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            field.lineBreakMode = .byTruncatingMiddle
            field.textColor = .labelColor
            field.drawsBackground = false
            field.isBordered = false
            field.toolTip = item.key
            return CenteredCellView(identifier: wrapId, hostedView: field)
        }

        private func textCell(
            tableView: NSTableView,
            reuseId: String,
            value: String,
            row: Int,
            isSource: Bool,
            languageCode: String?,
            isComment: Bool
        ) -> NSView {
            let wrapId = NSUserInterfaceItemIdentifier(reuseId + ".wrap")
            let fieldId = languageCode.map { "LangCell-\($0)" } ?? "CommentCell"

            if let wrap = tableView.makeView(withIdentifier: wrapId, owner: self) as? CenteredCellView,
               let field = wrap.subviews.first as? NSTextField {
                configure(field, value: value, row: row, isSource: isSource, isComment: isComment, fieldId: fieldId)
                return wrap
            }

            let field = NSTextField(string: "")
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false
            field.backgroundColor = .clear
            field.font = .systemFont(ofSize: 12)
            field.maximumNumberOfLines = 1
            field.lineBreakMode = .byTruncatingTail
            field.cell?.wraps = false
            field.cell?.isScrollable = true
            field.focusRingType = .default
            field.delegate = self
            field.target = self
            field.action = #selector(textFieldCommitted(_:))
            // Vertically center single-line text inside the field itself.
            if let cell = field.cell as? NSTextFieldCell {
                cell.alignment = .left
                // NSTextFieldCell doesn't expose vertical alignment; centering is via CenteredCellView.
            }

            configure(field, value: value, row: row, isSource: isSource, isComment: isComment, fieldId: fieldId)
            return CenteredCellView(identifier: wrapId, hostedView: field)
        }

        private func configure(
            _ field: NSTextField,
            value: String,
            row: Int,
            isSource: Bool,
            isComment: Bool,
            fieldId: String
        ) {
            field.stringValue = value
            field.isEditable = !isSource
            field.isSelectable = true
            field.tag = row
            field.identifier = NSUserInterfaceItemIdentifier(fieldId)
            field.toolTip = isComment ? "Comment".localized : fieldId.replacingOccurrences(of: "LangCell-", with: "")

            // Transparent fill so row background stays continuous (no white slabs / gaps).
            field.drawsBackground = false
            field.backgroundColor = .clear

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if isSource {
                field.textColor = .secondaryLabelColor
                field.placeholderString = nil
            } else if trimmed.isEmpty {
                field.textColor = .labelColor
                field.placeholderString = isComment ? "Comment".localized : "Missing".localized
            } else {
                field.textColor = .labelColor
                field.placeholderString = nil
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
            if let field = obj.object as? NSTextField {
                field.drawsBackground = true
                field.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.12)
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            if let field = obj.object as? NSTextField {
                field.drawsBackground = false
                field.backgroundColor = .clear
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
