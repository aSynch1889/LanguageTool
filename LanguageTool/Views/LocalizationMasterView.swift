import SwiftUI
import AppKit

struct LocalizationMasterView: View {
    @ObservedObject var viewModel: LocalizationMasterViewModel
    var onGoToConvert: (() -> Void)?
    var onOpenFile: (() -> Void)?

    init(
        viewModel: LocalizationMasterViewModel,
        onGoToConvert: (() -> Void)? = nil,
        onOpenFile: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onGoToConvert = onGoToConvert
        self.onOpenFile = onOpenFile
    }

    private var isEmptyReview: Bool {
        viewModel.document.filePath.isEmpty || viewModel.document.items.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEmptyReview && !viewModel.isLoading {
                emptyReviewChrome
            } else {
                headerBar
                Divider()
                ZStack {
                    contentBody
                    if viewModel.isLoading {
                        ProgressView("Working…".localized)
                            .padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Divider()
                footerBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 520, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var contentBody: some View {
        switch viewModel.layoutMode {
        case .split:
            masterDetailBody
        case .table:
            LocalizationMasterTableView(
                items: viewModel.filteredItems,
                availableLanguages: viewModel.document.availableLanguages,
                sourceLanguage: viewModel.document.sourceLanguage,
                onItemUpdate: { viewModel.updateItem($0) }
            )
        }
    }

    private var masterDetailBody: some View {
        HSplitView {
            keyListPane
                .frame(minWidth: 160, idealWidth: 240, maxWidth: 360)

            detailPane
                .frame(minWidth: 280)
        }
    }

    private var keyListPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keys".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.filteredItems.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: Binding(
                get: { viewModel.selectedKey },
                set: { viewModel.selectKey($0) }
            )) {
                ForEach(viewModel.filteredItems) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(rowBadgeColor(for: item))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.key)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                            if viewModel.document.hasMissingTranslation(item) {
                                Text("Missing translation".localized)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            } else if viewModel.document.isChanged(item) {
                                Text("Edited".localized)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .tag(item.key)
                    .contentShape(Rectangle())
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var detailPane: some View {
        Group {
            if let item = viewModel.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Key".localized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.key)
                                .font(.title3.monospaced())
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Comment".localized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Comment".localized, text: commentBinding(for: item), axis: .vertical)
                                .lineLimit(2...6)
                                .textFieldStyle(.roundedBorder)
                        }

                        Toggle("Include in batch translate".localized, isOn: selectionBinding(for: item))

                        Divider()

                        ForEach(orderedLanguages, id: \.self) { code in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(languageTitle(code))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    if code == viewModel.document.sourceLanguage {
                                        Text("Source".localized)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15), in: Capsule())
                                    }
                                }

                                if code == viewModel.document.sourceLanguage {
                                    Text(item.translations[code] ?? "")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                        .textSelection(.enabled)
                                } else {
                                    TextField(
                                        "Translation".localized,
                                        text: translationBinding(for: item, language: code),
                                        axis: .vertical
                                    )
                                    .lineLimit(3...10)
                                    .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Select a key to edit".localized)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var orderedLanguages: [String] {
        viewModel.document.availableLanguages.sorted { lhs, rhs in
            if lhs == viewModel.document.sourceLanguage { return true }
            if rhs == viewModel.document.sourceLanguage { return false }
            return lhs < rhs
        }
    }

    /// Full-page empty review — do not overlay on Split/Table (avoids ghost chrome).
    private var emptyReviewChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Review".localized, systemImage: "tablecells")
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            VStack(spacing: 14) {
                Spacer(minLength: 24)
                Image(systemName: "tablecells.badge.ellipsis")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No localization entries".localized)
                    .font(.title3.weight(.semibold))
                Text("Convert a file first, or open one here to review translations.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                HStack(spacing: 12) {
                    if let onGoToConvert {
                        Button("Go to Convert".localized, action: onGoToConvert)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                    if let onOpenFile {
                        Button("Open File…".localized, action: onOpenFile)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                }
                .padding(.top, 4)
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status + layout + filename on separate flexible rows so Chinese labels don't crush.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if viewModel.document.isDirty {
                        Label("Unsaved changes".localized, systemImage: "pencil.circle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Review".localized, systemImage: "tablecells")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption.weight(.semibold))
                .layoutPriority(1)

                Text(documentStatsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                layoutPicker
                    .layoutPriority(1)

                Text(URL(fileURLWithPath: viewModel.document.filePath).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .help(viewModel.document.filePath)
            }

            ViewThatFits(in: .horizontal) {
                filterSearchRow(searchMinWidth: 140, searchMaxWidth: 240)
                filterSearchRow(searchMinWidth: 96, searchMaxWidth: 180)
                VStack(alignment: .leading, spacing: 8) {
                    filterPicker
                    searchField(minWidth: 120, maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ViewThatFits(in: .horizontal) {
                batchOptionsRow(compact: false)
                batchOptionsRow(compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.lastOperationSucceeded ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var documentStatsText: String {
        var parts: [String] = [
            "%lld keys · %lld languages".localizedFormat(
                viewModel.document.items.count,
                viewModel.document.availableLanguages.count
            )
        ]
        if viewModel.document.missingCount > 0 {
            parts.append("· %lld missing".localizedFormat(viewModel.document.missingCount))
        }
        if viewModel.document.changedCount > 0 {
            parts.append("· %lld changed".localizedFormat(viewModel.document.changedCount))
        }
        return parts.joined(separator: " ")
    }

    private var layoutPicker: some View {
        Picker("Layout".localized, selection: $viewModel.layoutMode) {
            ForEach(MasterLayoutMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // Intrinsic width + leading alignment — avoid minWidth frames that center short locales.
        .fixedSize(horizontal: true, vertical: false)
    }

    private var filterPicker: some View {
        HStack(spacing: 8) {
            Text("Filter".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()

            Picker("Filter".localized, selection: $viewModel.rowFilter) {
                ForEach(LocalizationRowFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
    }

    private func searchField(minWidth: CGFloat, maxWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search".localized, text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
        }
        .frame(minWidth: minWidth, maxWidth: maxWidth, alignment: .leading)
    }

    private func filterSearchRow(searchMinWidth: CGFloat, searchMaxWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            filterPicker
            Spacer(minLength: 8)
            searchField(minWidth: searchMinWidth, maxWidth: searchMaxWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func batchOptionsRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 10 : 16) {
            Toggle(isOn: $viewModel.translateSelectedOnly) {
                Text(compact ? "Checked only".localized : "Translate only checked rows".localized)
                    .font(.caption)
                    .lineLimit(1)
            }
            .toggleStyle(.checkbox)
            .layoutPriority(1)
            .help("Translate only checked rows".localized)

            Toggle(isOn: $viewModel.skipExistingTranslations) {
                Text("Skip existing".localized)
                    .font(.caption)
                    .lineLimit(1)
            }
            .toggleStyle(.checkbox)
            .layoutPriority(1)

            if !compact {
                Divider()
                    .frame(height: 16)
            }

            Button("Select All".localized) { viewModel.setBatchSelection(true) }
                .buttonStyle(.borderless)
                .fixedSize()
            Button(compact ? "None".localized : "Select None".localized) { viewModel.setBatchSelection(false) }
                .buttonStyle(.borderless)
                .fixedSize()

            Spacer(minLength: 0)
        }
    }

    private var footerBar: some View {
        ViewThatFits(in: .horizontal) {
            footerControls(compact: false)
            footerControls(compact: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private func footerControls(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Menu {
                if viewModel.addableLanguages.isEmpty {
                    Text("No languages to add".localized)
                } else {
                    ForEach(viewModel.addableLanguages) { language in
                        Button("\(language.localizedName) (\(language.code))") {
                            viewModel.addLanguage(language.code)
                        }
                    }
                }
            } label: {
                Text(compact ? "Language".localized : "Add Language".localized)
            }
            .fixedSize()
            .layoutPriority(1)

            Spacer(minLength: 4)

            if compact {
                Menu("More".localized) {
                    Button("Reload Source".localized) {
                        Task { await viewModel.reload() }
                    }
                    .disabled(viewModel.isLoading)
                    Button("Export CSV".localized) {
                        viewModel.exportCSV()
                    }
                    .disabled(viewModel.document.items.isEmpty)
                    Button("Save".localized) {
                        viewModel.save()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(viewModel.document.items.isEmpty || viewModel.isLoading)
                }
                .fixedSize()
            } else {
                Button("Reload Source".localized) {
                    Task { await viewModel.reload() }
                }
                .disabled(viewModel.isLoading)
                .fixedSize()

                Button("Export CSV".localized) {
                    viewModel.exportCSV()
                }
                .disabled(viewModel.document.items.isEmpty)
                .fixedSize()

                Button("Save".localized) {
                    viewModel.save()
                }
                .disabled(viewModel.document.items.isEmpty || viewModel.isLoading)
                .keyboardShortcut("s", modifiers: .command)
                .fixedSize()
            }

            if viewModel.isLoading {
                Button("Cancel".localized) {
                    viewModel.cancelTranslation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .fixedSize()
                .layoutPriority(2)
            } else {
                Button(compact ? "Translate".localized : "Translate Now".localized) {
                    viewModel.translateNow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.document.items.isEmpty)
                .fixedSize()
                .layoutPriority(2)
            }
        }
    }

    // MARK: - Bindings

    private func rowBadgeColor(for item: TranslationItem) -> Color {
        if viewModel.document.hasMissingTranslation(item) { return .orange }
        if viewModel.document.isChanged(item) { return .blue }
        return .green.opacity(0.7)
    }

    private func languageTitle(_ code: String) -> String {
        if let language = Language.supportedLanguages.first(where: { $0.code == code }) {
            return "\(code) · \(language.localizedName)"
        }
        return code
    }

    private func commentBinding(for item: TranslationItem) -> Binding<String> {
        Binding(
            get: { viewModel.document.items.first(where: { $0.key == item.key })?.comment ?? item.comment },
            set: { newValue in
                var updated = viewModel.document.items.first(where: { $0.key == item.key }) ?? item
                updated.comment = newValue
                viewModel.updateItem(updated)
            }
        )
    }

    private func selectionBinding(for item: TranslationItem) -> Binding<Bool> {
        Binding(
            get: { viewModel.document.items.first(where: { $0.key == item.key })?.isSelected ?? item.isSelected },
            set: { newValue in
                var updated = viewModel.document.items.first(where: { $0.key == item.key }) ?? item
                updated.isSelected = newValue
                viewModel.updateItem(updated)
            }
        )
    }

    private func translationBinding(for item: TranslationItem, language: String) -> Binding<String> {
        Binding(
            get: {
                viewModel.document.items.first(where: { $0.key == item.key })?.translations[language]
                    ?? item.translations[language]
                    ?? ""
            },
            set: { newValue in
                var updated = viewModel.document.items.first(where: { $0.key == item.key }) ?? item
                updated.translations[language] = newValue
                viewModel.updateItem(updated)
            }
        )
    }
}

#if DEBUG
struct LocalizationMasterView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationMasterView(viewModel: LocalizationMasterViewModel())
    }
}
#endif
