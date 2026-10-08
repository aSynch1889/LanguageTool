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
            ZStack {
                contentBody

                if viewModel.document.items.isEmpty && !viewModel.isLoading {
                    emptyState
                }

                if viewModel.isLoading {
                    ProgressView("Working…")
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            Divider()
            footerBar
        }
        .frame(minWidth: 960, minHeight: 640)
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
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            detailPane
                .frame(minWidth: 420)
        }
    }

    private var keyListPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keys")
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
                                Text("Missing translation")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            } else if viewModel.document.isChanged(item) {
                                Text("Edited")
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
                            Text("Key")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.key)
                                .font(.title3.monospaced())
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Comment")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Comment", text: commentBinding(for: item), axis: .vertical)
                                .lineLimit(2...6)
                                .textFieldStyle(.roundedBorder)
                        }

                        Toggle("Include in batch translate", isOn: selectionBinding(for: item))

                        Divider()

                        ForEach(orderedLanguages, id: \.self) { code in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(languageTitle(code))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    if code == viewModel.document.sourceLanguage {
                                        Text("Source")
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
                                        "Translation",
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
                    Text("Select a key to edit")
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("No localization entries")
                .font(.headline)
            Text("Open a source file from the main window, then launch Localization Master.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(24)
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if viewModel.document.isDirty {
                    Label("Unsaved changes", systemImage: "pencil.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label("Localization Master", systemImage: "tablecells")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("·")
                    .foregroundStyle(.quaternary)

                Text("\(viewModel.document.items.count) keys · \(viewModel.document.availableLanguages.count) languages")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.document.missingCount > 0 {
                    Text("· \(viewModel.document.missingCount) missing")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if viewModel.document.changedCount > 0 {
                    Text("· \(viewModel.document.changedCount) changed")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Spacer()

                Picker("Layout", selection: $viewModel.layoutMode) {
                    ForEach(MasterLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Text(viewModel.document.filePath.isEmpty
                     ? "No file"
                     : URL(fileURLWithPath: viewModel.document.filePath).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(viewModel.document.filePath)
            }

            HStack(spacing: 14) {
                Picker("Filter", selection: $viewModel.rowFilter) {
                    ForEach(LocalizationRowFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Toggle("Translate only checked rows".localized, isOn: $viewModel.translateSelectedOnly)
                Toggle("Skip existing".localized, isOn: $viewModel.skipExistingTranslations)

                Button("Select All") { viewModel.setBatchSelection(true) }
                    .buttonStyle(.borderless)
                Button("Select None") { viewModel.setBatchSelection(false) }
                    .buttonStyle(.borderless)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search".localized, text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 160, idealWidth: 220, maxWidth: 260)
                }
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.lastOperationSucceeded ? Color.secondary : Color.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

            Button("Export CSV".localized) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
