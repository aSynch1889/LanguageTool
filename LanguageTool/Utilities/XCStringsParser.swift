import Foundation

struct XCStringsTranslationEntry: Sendable, Equatable {
    let key: String
    let sourceValue: String
    let existingTranslations: [String: String]
    let comment: String

    init(key: String, sourceValue: String, existingTranslations: [String: String], comment: String = "") {
        self.key = key
        self.sourceValue = sourceValue
        self.existingTranslations = existingTranslations
        self.comment = comment
    }
}

enum XCStringsParser {
    static func parse(data: Data) throws -> (entries: [XCStringsTranslationEntry], sourceLanguage: String) {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let strings = jsonObject["strings"] as? [String: Any],
              let sourceLanguage = jsonObject["sourceLanguage"] as? String else {
            throw NSError(
                domain: "XCStringsParser",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid xcstrings JSON structure"]
            )
        }

        var entries: [XCStringsTranslationEntry] = []

        for key in strings.keys.sorted() {
            guard let entry = strings[key] as? [String: Any] else { continue }
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let comment = entry["comment"] as? String ?? ""

            var sourceValue = ""
            if let sourceLocalization = localizations[sourceLanguage] as? [String: Any],
               let stringUnit = sourceLocalization["stringUnit"] as? [String: Any],
               let value = stringUnit["value"] as? String {
                sourceValue = value
            } else if let source = entry["source"] as? [String: Any],
                      let stringUnit = source["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String {
                sourceValue = value
            }

            if sourceValue.isEmpty { continue }

            var keyTranslations: [String: String] = [:]
            for (langCode, localization) in localizations {
                if let locDict = localization as? [String: Any],
                   let stringUnit = locDict["stringUnit"] as? [String: Any],
                   let translatedValue = stringUnit["value"] as? String,
                   !translatedValue.isEmpty {
                    keyTranslations[langCode] = translatedValue
                }
            }

            entries.append(
                XCStringsTranslationEntry(
                    key: key,
                    sourceValue: sourceValue,
                    existingTranslations: keyTranslations,
                    comment: comment
                )
            )
        }

        return (entries, sourceLanguage)
    }

    static func parseFile(at path: String) throws -> (entries: [XCStringsTranslationEntry], sourceLanguage: String) {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try parse(data: data)
    }
}
