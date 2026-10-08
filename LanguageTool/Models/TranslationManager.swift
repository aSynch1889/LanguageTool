import Foundation

enum TranslationParseError: LocalizedError {
    case emptyResult
    case invalidEncoding
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .emptyResult:
            return "No translation items found in source file"
        case .invalidEncoding:
            return "Invalid strings file encoding"
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

class TranslationManager {
    static let shared = TranslationManager()

    private init() {}

    func parseInputFile(at path: String, platform: PlatformType) async throws -> [TranslationItem] {
        let fileURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: fileURL)

        let items: [TranslationItem]
        switch platform {
        case .iOS:
            if path.hasSuffix(".xcstrings") {
                items = try parseXCStrings(data: data)
            } else {
                items = try parseStringsFile(data: data)
            }
        case .electron:
            items = try parseJsonFile(data: data)
        case .flutter:
            items = try parseArbFile(data: data)
        }

        if items.isEmpty {
            throw TranslationParseError.emptyResult
        }
        return items
    }

    /// Soft-fail wrapper for call sites that still expect an empty array.
    func parseInputFileOrEmpty(at path: String, platform: PlatformType) async -> [TranslationItem] {
        do {
            return try await parseInputFile(at: path, platform: platform)
        } catch {
            print("Error parsing file: \(error.localizedDescription)")
            return []
        }
    }

    private func parseXCStrings(data: Data) throws -> [TranslationItem] {
        let parsed = try XCStringsParser.parse(data: data)
        return parsed.entries.map { entry in
            var translations = entry.existingTranslations
            translations[parsed.sourceLanguage] = entry.sourceValue
            return TranslationItem(
                key: entry.key,
                translations: translations,
                comment: entry.comment
            )
        }
    }

    private func parseStringsFile(data: Data) throws -> [TranslationItem] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw TranslationParseError.invalidEncoding
        }

        var translations: [TranslationItem] = []
        let lines = content.components(separatedBy: .newlines)
        let regex = try NSRegularExpression(pattern: "\"(.*)\"\\s*=\\s*\"(.*)\";")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("//") else { continue }

            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range),
                  let keyRange = Range(match.range(at: 1), in: trimmed),
                  let valueRange = Range(match.range(at: 2), in: trimmed) else {
                continue
            }

            translations.append(TranslationItem(
                key: String(trimmed[keyRange]),
                translations: ["en": String(trimmed[valueRange])]
            ))
        }

        return translations
    }

    private func parseJsonFile(data: Data) throws -> [TranslationItem] {
        let json = try JSONDecoder().decode([String: String].self, from: data)
        return json.map { key, value in
            TranslationItem(key: key, translations: ["en": value])
        }
    }

    private func parseArbFile(data: Data) throws -> [TranslationItem] {
        let json = try JSONDecoder().decode([String: String].self, from: data)
        return json.compactMap { key, value in
            guard !key.hasPrefix("@") else { return nil }
            return TranslationItem(key: key, translations: ["en": value])
        }
    }
}
