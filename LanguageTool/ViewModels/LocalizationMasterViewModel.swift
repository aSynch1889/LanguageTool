import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum MasterLayoutMode: String, CaseIterable, Identifiable {
    case split
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: return "Split".localized
        case .table: return "Table".localized
        }
    }

    /// Icon for the compact header toggle (shows the mode you would switch *to*).
    var toggleSystemImage: String {
        switch self {
        case .split: return "tablecells"
        case .table: return "sidebar.left"
        }
    }

    var toggled: MasterLayoutMode {
        switch self {
        case .split: return .table
        case .table: return .split
        }
    }
}

@MainActor
final class LocalizationMasterViewModel: ObservableObject {
    @Published var document = LocalizationDocument()
    @Published var searchText = ""
    @Published var rowFilter: LocalizationRowFilter = .all
    @Published var layoutMode: MasterLayoutMode = .table
    @Published var selectedKey: String?
    @Published var translateSelectedOnly = true
    @Published var skipExistingTranslations = true
    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var lastOperationSucceeded = false

    private var translateTask: Task<Void, Never>?

    var filteredItems: [TranslationItem] {
        var items = document.items

        switch rowFilter {
        case .all:
            break
        case .missing:
            items = items.filter { document.hasMissingTranslation($0) }
        case .changed:
            items = items.filter { document.isChanged($0) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.key.localizedCaseInsensitiveContains(query)
                || item.comment.localizedCaseInsensitiveContains(query)
                || item.translations.values.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var selectedItem: TranslationItem? {
        guard let selectedKey else { return nil }
        return document.items.first { $0.key == selectedKey }
    }

    var addableLanguages: [Language] {
        let existing = Set(document.availableLanguages)
        return Language.supportedLanguages.filter { !existing.contains($0.code) }
    }

    func load(path: String, platform: PlatformType) async {
        isLoading = true
        statusMessage = ""
        do {
            try await document.load(from: path, platform: platform)
            selectedKey = document.items.first?.key
            statusMessage = "Loaded %lld keys".localizedFormat(document.items.count)
            lastOperationSucceeded = true
        } catch {
            statusMessage = "Load failed: %@".localizedFormat(error.localizedDescription)
            lastOperationSucceeded = false
            showAlert(message: statusMessage, isError: true)
        }
        isLoading = false
        objectWillChange.send()
    }

    /// Open conversion output (or any path) for review, optionally ensuring languages exist.
    func loadForReview(
        path: String,
        platform: PlatformType,
        languageCodes: [String] = [],
        skipExisting: Bool? = nil
    ) async {
        if let skipExisting {
            skipExistingTranslations = skipExisting
        }
        await load(path: path, platform: platform)
        for code in languageCodes {
            document.addLanguage(code)
        }
        if !languageCodes.isEmpty {
            objectWillChange.send()
        }
    }

    func selectKey(_ key: String?) {
        selectedKey = key
    }

    func updateItem(_ item: TranslationItem) {
        document.updateItem(item)
        if selectedKey == nil {
            selectedKey = item.key
        }
        objectWillChange.send()
    }

    /// Returns `true` when the window may close.
    @discardableResult
    func confirmCloseIfNeeded() -> Bool {
        guard document.isDirty else { return true }

        let alert = NSAlert()
        alert.messageText = "Save changes before closing?".localized
        alert.informativeText = "You have unsaved edits in Localization Master.".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save".localized)
        alert.addButton(withTitle: "Don't Save".localized)
        alert.addButton(withTitle: "Cancel".localized)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            do {
                try document.save()
                statusMessage = "Saved".localized
                lastOperationSucceeded = true
                objectWillChange.send()
                return true
            } catch {
                statusMessage = "Save failed: %@".localizedFormat(error.localizedDescription)
                lastOperationSucceeded = false
                showAlert(message: statusMessage, isError: true)
                return false
            }
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    func addLanguage(_ code: String) {
        document.addLanguage(code)
        statusMessage = "Added language %@".localizedFormat(code)
        lastOperationSucceeded = true
        objectWillChange.send()
    }

    func setBatchSelection(_ selected: Bool) {
        let updated = document.items.map { item -> TranslationItem in
            var copy = item
            copy.isSelected = selected
            return copy
        }
        document.replaceItems(updated, markDirty: false)
        objectWillChange.send()
    }

    func save() {
        do {
            try document.save()
            statusMessage = "Saved to %@".localizedFormat(URL(fileURLWithPath: document.filePath).lastPathComponent)
            lastOperationSucceeded = true
            objectWillChange.send()
            showAlert(message: statusMessage)
        } catch {
            statusMessage = "Save failed: %@".localizedFormat(error.localizedDescription)
            lastOperationSucceeded = false
            showAlert(message: statusMessage, isError: true)
        }
    }

    /// Saves document content back to the source file path (real sync).
    func syncToSource() {
        save()
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "translations.csv"
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    try self.document.exportCSV(to: url)
                    self.statusMessage = "CSV exported".localized
                    self.lastOperationSucceeded = true
                    NSWorkspace.shared.open(url)
                } catch {
                    self.statusMessage = "Export failed: %@".localizedFormat(error.localizedDescription)
                    self.lastOperationSucceeded = false
                    self.showAlert(message: self.statusMessage, isError: true)
                }
            }
        }
    }

    func reload() async {
        guard !document.filePath.isEmpty else { return }
        if document.isDirty {
            let alert = NSAlert()
            alert.messageText = "Discard unsaved changes?".localized
            alert.informativeText = "Reloading will discard edits that have not been saved.".localized
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Reload".localized)
            alert.addButton(withTitle: "Cancel".localized)
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }
        await load(path: document.filePath, platform: document.platform)
    }

    func translateNow() {
        translateTask?.cancel()
        translateTask = Task {
            await performTranslation()
        }
    }

    func cancelTranslation() {
        translateTask?.cancel()
        translateTask = nil
        isLoading = false
        statusMessage = "Translation cancelled".localized
        lastOperationSucceeded = false
    }

    private func performTranslation() async {
        isLoading = true
        statusMessage = "Translating…".localized
        lastOperationSucceeded = false

        let sourceLanguage = document.sourceLanguage
        var working = document.items
        let candidateIndices = working.indices.filter { index in
            !translateSelectedOnly || working[index].isSelected
        }

        guard !candidateIndices.isEmpty else {
            isLoading = false
            statusMessage = "No rows selected for translation".localized
            return
        }

        let targetLanguages = document.availableLanguages.filter { $0 != sourceLanguage }
        guard !targetLanguages.isEmpty else {
            isLoading = false
            statusMessage = "No target languages to translate".localized
            return
        }

        var succeeded = 0
        var failed: [String] = []

        for language in targetLanguages {
            if Task.isCancelled {
                statusMessage = "Translation cancelled".localized
                isLoading = false
                return
            }

            var sourceTexts: [String] = []
            var existing: [String?] = []
            var mappedIndices: [Int] = []

            for idx in candidateIndices {
                let item = working[idx]
                if let source = preferredSourceText(from: item, sourceLanguage: sourceLanguage), !source.isEmpty {
                    // Skip translating into the same language as the source text language when equal.
                    if language == sourceLanguage { continue }
                    sourceTexts.append(source)
                    existing.append(item.translations[language])
                    mappedIndices.append(idx)
                }
            }

            if sourceTexts.isEmpty { continue }

            statusMessage = "Translating %@…".localizedFormat(language)

            do {
                let result = try await AIServiceV2.shared.batchTranslateWithExisting(
                    texts: sourceTexts,
                    to: LanguagePrompt.label(for: language),
                    existingTranslations: existing,
                    skipExisting: skipExistingTranslations
                )

                for (translationIndex, itemIndex) in mappedIndices.enumerated() where translationIndex < result.translations.count {
                    working[itemIndex].translations[language] = result.translations[translationIndex]
                }
                succeeded += 1
            } catch is CancellationError {
                document.replaceItems(working, markDirty: true)
                statusMessage = "Translation cancelled".localized
                isLoading = false
                return
            } catch {
                failed.append(language)
            }
        }

        document.replaceItems(working, markDirty: true)
        isLoading = false
        objectWillChange.send()

        if failed.isEmpty {
            statusMessage = "Translated %lld language(s). Save to persist.".localizedFormat(succeeded)
            lastOperationSucceeded = true
        } else {
            statusMessage = "OK: %lld · Failed: %@. Save to persist.".localizedFormat(
                succeeded,
                failed.joined(separator: ", ")
            )
            lastOperationSucceeded = succeeded > 0
        }
    }

    private func preferredSourceText(from item: TranslationItem, sourceLanguage: String) -> String? {
        if let value = item.translations[sourceLanguage], !value.isEmpty {
            return value
        }
        for code in ["en", "zh-Hans", "zh-Hant"] {
            if let value = item.translations[code], !value.isEmpty {
                return value
            }
        }
        return item.translations.values.first { !$0.isEmpty }
    }

    private func showAlert(message: String, isError: Bool = false) {
        let alert = NSAlert()
        alert.messageText = (isError ? "Error" : "Success").localized
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }
}
