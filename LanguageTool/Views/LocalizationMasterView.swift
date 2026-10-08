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
                LocalizationMasterTableView(
                    items: viewModel.filteredItems,
                    availableLanguages: viewModel.document.availableLanguages,
                    sourceLanguage: viewModel.document.sourceLanguage,
                    onItemUpdate: { viewModel.updateItem($0) }
                )

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

                Spacer()

                Text(viewModel.document.filePath.isEmpty
                     ? "No file"
                     : URL(fileURLWithPath: viewModel.document.filePath).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(viewModel.document.filePath)
            }

            HStack(spacing: 14) {
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
                        .frame(minWidth: 180, idealWidth: 240, maxWidth: 280)
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
}

#if DEBUG
struct LocalizationMasterView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationMasterView(viewModel: LocalizationMasterViewModel())
    }
}
#endif
