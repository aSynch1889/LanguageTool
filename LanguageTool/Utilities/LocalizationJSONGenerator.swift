import Foundation

struct LocalizationGenerationResult: Sendable {
    let data: Data?
    let succeededLanguages: Int
    let failedLanguages: [String]
    let needsReviewCount: Int

    var report: String {
        var parts: [String] = []
        if succeededLanguages > 0 {
            parts.append("Languages OK: \(succeededLanguages)")
        }
        if !failedLanguages.isEmpty {
            parts.append("Failed: \(failedLanguages.joined(separator: ", "))")
        }
        if needsReviewCount > 0 {
            parts.append("Needs review: \(needsReviewCount)")
        }
        return parts.joined(separator: " · ")
    }

    var isEmpty: Bool { report.isEmpty }
}

class LocalizationJSONGenerator {
    static let maxConcurrentLanguages = 3

    static func generateJSON(
        for entries: [XCStringsTranslationEntry],
        languages: [String],
        sourceLanguage: String,
        skipExistingTranslations: Bool = true
    ) async -> LocalizationGenerationResult {
        var localizationData: [String: Any] = [
            "version": "1.0",
            "sourceLanguage": sourceLanguage,
            "strings": [:]
        ]

        var stringsDict: [String: Any] = [:]

        for entry in entries {
            var localizations: [String: Any] = [
                sourceLanguage: [
                    "stringUnit": [
                        "state": "translated",
                        "value": entry.sourceValue
                    ]
                ]
            ]

            for (langCode, value) in entry.existingTranslations where !value.isEmpty {
                localizations[langCode] = [
                    "stringUnit": [
                        "state": "translated",
                        "value": value
                    ]
                ]
            }

            stringsDict[entry.key] = ["localizations": localizations]
        }

        let targetLanguages = languages.filter { $0 != sourceLanguage }
        var succeeded = 0
        var failed: [String] = []
        var needsReview = 0

        await withTaskGroup(of: (String, Result<[String], Error>).self) { group in
            var iterator = targetLanguages.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                while inFlight < maxConcurrentLanguages, let language = iterator.next() {
                    inFlight += 1
                    group.addTask {
                        do {
                            try Task.checkCancellation()
                            let existingTranslationsForLanguage = entries.map { $0.existingTranslations[language] }
                            let result = try await AIServiceV2.shared.batchTranslateWithExisting(
                                texts: entries.map(\.sourceValue),
                                to: LanguagePrompt.label(for: language),
                                existingTranslations: existingTranslationsForLanguage,
                                skipExisting: skipExistingTranslations
                            )
                            return (language, .success(result.translations))
                        } catch {
                            return (language, .failure(error))
                        }
                    }
                }
            }

            enqueueNext()

            for await (language, outcome) in group {
                inFlight -= 1
                switch outcome {
                case .success(let translations):
                    succeeded += 1
                    for (index, entry) in entries.enumerated() where index < translations.count {
                        if var localizations = stringsDict[entry.key] as? [String: Any],
                           var localizationsDict = localizations["localizations"] as? [String: Any] {
                            let translationValue = translations[index]
                            if translationValue.isEmpty { needsReview += 1 }
                            localizationsDict[language] = [
                                "stringUnit": [
                                    "state": translationValue.isEmpty ? "needs_review" : "translated",
                                    "value": translationValue
                                ]
                            ]
                            localizations["localizations"] = localizationsDict
                            stringsDict[entry.key] = localizations
                        }
                    }
                    print("✅ Batch translation successful [\(language)]")
                case .failure(let error):
                    if error is CancellationError {
                        failed.append(language)
                        print("❌ Batch translation cancelled [\(language)]")
                    } else {
                        failed.append(language)
                        print("❌ Batch translation failed [\(language)]: \(error.localizedDescription)")
                        for entry in entries {
                            if var localizations = stringsDict[entry.key] as? [String: Any],
                               var localizationsDict = localizations["localizations"] as? [String: Any] {
                                localizationsDict[language] = [
                                    "stringUnit": [
                                        "state": "needs_review",
                                        "value": ""
                                    ]
                                ]
                                localizations["localizations"] = localizationsDict
                                stringsDict[entry.key] = localizations
                                needsReview += 1
                            }
                        }
                    }
                }
                enqueueNext()
            }
        }

        localizationData["strings"] = stringsDict

        do {
            let data = try JSONSerialization.data(withJSONObject: localizationData, options: [.prettyPrinted, .sortedKeys])
            return LocalizationGenerationResult(
                data: data,
                succeededLanguages: succeeded,
                failedLanguages: failed,
                needsReviewCount: needsReview
            )
        } catch {
            print("❌ 生成 JSON 失败: \(error)")
            return LocalizationGenerationResult(
                data: nil,
                succeededLanguages: succeeded,
                failedLanguages: failed,
                needsReviewCount: needsReview
            )
        }
    }
}
