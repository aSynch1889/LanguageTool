import Foundation

enum LocalizationDocumentError: LocalizedError {
    case unsupportedFormat
    case invalidPath
    case encodeFailed
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported localization file format"
        case .invalidPath: return "Invalid file path"
        case .encodeFailed: return "Failed to encode localization document"
        case .emptyDocument: return "Document has no translation items"
        }
    }
}

enum LocalizationRowFilter: String, CaseIterable, Identifiable {
    case all
    case missing
    case changed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .missing: return "Missing"
        case .changed: return "Changed"
        }
    }
}

/// Snapshot used to detect per-key edits since last load/save.
struct TranslationItemBaseline: Equatable {
    let translations: [String: String]
    let comment: String
}

/// In-memory localization document with load / merge-save / CSV export.
@MainActor
final class LocalizationDocument: ObservableObject {
    @Published private(set) var items: [TranslationItem] = []
    @Published private(set) var sourceLanguage: String = "en"
    @Published private(set) var filePath: String = ""
    @Published private(set) var platform: PlatformType = .iOS
    @Published private(set) var isDirty: Bool = false

    private var originalXCStringsJSON: [String: Any]?
    private var baselines: [String: TranslationItemBaseline] = [:]

    var availableLanguages: [String] {
        var codes = Set<String>()
        for item in items {
            codes.formUnion(item.translations.keys)
        }
        if !sourceLanguage.isEmpty {
            codes.insert(sourceLanguage)
        }
        return Array(codes).sorted()
    }

    var targetLanguages: [String] {
        availableLanguages.filter { $0 != sourceLanguage }
    }

    var fileExtension: String {
        (filePath as NSString).pathExtension.lowercased()
    }

    var missingCount: Int {
        items.filter { hasMissingTranslation($0) }.count
    }

    var changedCount: Int {
        items.filter { isChanged($0) }.count
    }

    func load(from path: String, platform: PlatformType) async throws {
        let parsed = try await TranslationManager.shared.parseInputFile(at: path, platform: platform)
        self.platform = platform
        self.filePath = path
        self.items = parsed
        self.isDirty = false
        self.originalXCStringsJSON = nil

        if path.lowercased().hasSuffix(".xcstrings") {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let parsedXC = try XCStringsParser.parse(data: data)
            self.sourceLanguage = parsedXC.sourceLanguage
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.originalXCStringsJSON = json
            }
        } else {
            // Prefer explicit en / zh-Hans when present.
            if items.contains(where: { $0.translations["en"] != nil }) {
                sourceLanguage = "en"
            } else if items.contains(where: { $0.translations["zh-Hans"] != nil }) {
                sourceLanguage = "zh-Hans"
            } else {
                sourceLanguage = items.first?.translations.keys.sorted().first ?? "en"
            }
        }
        captureBaseline()
    }

    /// Load an already-parsed item set (e.g. after conversion) as a review document.
    func loadItems(
        _ parsed: [TranslationItem],
        path: String,
        platform: PlatformType,
        sourceLanguage: String?
    ) {
        self.platform = platform
        self.filePath = path
        self.items = parsed
        self.isDirty = false
        self.originalXCStringsJSON = nil
        if let sourceLanguage, !sourceLanguage.isEmpty {
            self.sourceLanguage = sourceLanguage
        } else if parsed.contains(where: { $0.translations["en"] != nil }) {
            self.sourceLanguage = "en"
        } else {
            self.sourceLanguage = parsed.first?.translations.keys.sorted().first ?? "en"
        }
        if path.lowercased().hasSuffix(".xcstrings"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            originalXCStringsJSON = json
            if let src = json["sourceLanguage"] as? String {
                self.sourceLanguage = src
            }
        }
        captureBaseline()
    }

    func captureBaseline() {
        baselines = Dictionary(uniqueKeysWithValues: items.map { item in
            (item.key, TranslationItemBaseline(translations: item.translations, comment: item.comment))
        })
    }

    func hasMissingTranslation(_ item: TranslationItem) -> Bool {
        let targets = targetLanguages
        guard !targets.isEmpty else { return false }
        return targets.contains { code in
            (item.translations[code] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func isChanged(_ item: TranslationItem) -> Bool {
        guard let baseline = baselines[item.key] else { return true }
        return baseline.translations != item.translations || baseline.comment != item.comment
    }

    func replaceItems(_ newItems: [TranslationItem], markDirty: Bool = true) {
        items = newItems
        if markDirty { isDirty = true }
    }

    func updateItem(_ item: TranslationItem) {
        guard let index = items.firstIndex(where: { $0.key == item.key }) else { return }
        let previous = items[index]
        items[index] = item
        let contentChanged = previous.translations != item.translations || previous.comment != item.comment
        if contentChanged {
            isDirty = true
        }
    }

    func addLanguage(_ languageCode: String) {
        guard !languageCode.isEmpty else { return }
        var changed = false
        for index in items.indices {
            if items[index].translations[languageCode] == nil {
                items[index].translations[languageCode] = ""
                changed = true
            }
        }
        if changed { isDirty = true }
    }

    /// Saves current in-memory items to `path` (defaults to loaded path).
    func save(to path: String? = nil) throws {
        let target = path ?? filePath
        guard !target.isEmpty else { throw LocalizationDocumentError.invalidPath }
        guard !items.isEmpty else { throw LocalizationDocumentError.emptyDocument }

        let ext = (target as NSString).pathExtension.lowercased()
        switch ext {
        case "xcstrings":
            try saveXCStrings(to: target)
        case "arb":
            try saveFlatJSON(to: target, language: sourceLanguage, arbStyle: true)
        case "json":
            try saveFlatJSON(to: target, language: sourceLanguage, arbStyle: false)
        case "strings":
            try saveStrings(to: target, language: sourceLanguage)
        default:
            throw LocalizationDocumentError.unsupportedFormat
        }

        filePath = target
        isDirty = false
        captureBaseline()
    }

    func exportCSV(to url: URL) throws {
        let languages = availableLanguages
        var csv = "Key,"
        csv += languages.joined(separator: ",")
        csv += ",Comment\n"

        for item in items.sorted(by: { $0.key < $1.key }) {
            let escapedKey = csvEscape(item.key)
            let values = languages.map { csvEscape(item.translations[$0] ?? "") }
            csv += ([escapedKey] + values + [csvEscape(item.comment)]).joined(separator: ",")
            csv += "\n"
        }

        let bom = Data([0xEF, 0xBB, 0xBF])
        try (bom + Data(csv.utf8)).write(to: url, options: .atomic)
    }

    // MARK: - Writers

    private func saveXCStrings(to path: String) throws {
        var root: [String: Any]
        if let original = originalXCStringsJSON {
            root = original
        } else {
            root = [
                "version": "1.0",
                "sourceLanguage": sourceLanguage,
                "strings": [String: Any]()
            ]
        }

        root["sourceLanguage"] = sourceLanguage
        if root["version"] == nil {
            root["version"] = "1.0"
        }

        var strings = root["strings"] as? [String: Any] ?? [:]

        for item in items {
            var entry = strings[item.key] as? [String: Any] ?? [:]
            if !item.comment.isEmpty {
                entry["comment"] = item.comment
            } else {
                entry.removeValue(forKey: "comment")
            }

            var localizations = entry["localizations"] as? [String: Any] ?? [:]
            for (lang, value) in item.translations {
                if value.isEmpty {
                    // Keep empty as needs_review so structure remains.
                    localizations[lang] = [
                        "stringUnit": [
                            "state": "needs_review",
                            "value": ""
                        ]
                    ]
                } else {
                    localizations[lang] = [
                        "stringUnit": [
                            "state": "translated",
                            "value": value
                        ]
                    ]
                }
            }
            entry["localizations"] = localizations
            strings[item.key] = entry
        }

        root["strings"] = strings

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        originalXCStringsJSON = root
    }

    private func saveFlatJSON(to path: String, language: String, arbStyle: Bool) throws {
        var dict: [String: String] = [:]
        for item in items {
            let value = item.translations[language] ?? item.translations.values.first ?? ""
            dict[item.key] = value
            if arbStyle, !item.comment.isEmpty {
                dict["@\(item.key)"] = item.comment
            }
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func saveStrings(to path: String, language: String) throws {
        var lines: [String] = []
        for item in items.sorted(by: { $0.key < $1.key }) {
            if !item.comment.isEmpty {
                lines.append("/* \(item.comment) */")
            }
            let value = item.translations[language] ?? ""
            lines.append("\"\(escapeStrings(item.key))\" = \"\(escapeStrings(value))\";")
        }
        try lines.joined(separator: "\n").write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    private func escapeStrings(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + escaped + "\""
    }
}
