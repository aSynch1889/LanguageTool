import Foundation

enum BatchTranslationParseError: Error, Equatable {
    case emptyResponse
    case invalidJSON
    case countMismatch(expected: Int, actual: Int)
}

/// Parses structured batch-translation responses (JSON array preferred, `|||` legacy fallback).
enum BatchTranslationParser {
    static let defaultChunkSize = 40

    static func chunk<T>(_ items: [T], size: Int = defaultChunkSize) -> [[T]] {
        guard size > 0, !items.isEmpty else { return items.isEmpty ? [] : [items] }
        var result: [[T]] = []
        var index = 0
        while index < items.count {
            let end = min(index + size, items.count)
            result.append(Array(items[index..<end]))
            index = end
        }
        return result
    }

    static func buildPrompt(texts: [String], targetLanguage: String, glossaryHint: String) -> String {
        let payload: [[String: Any]] = texts.enumerated().map { index, text in
            ["index": index, "text": text]
        }
        let jsonData = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data("[]".utf8)
        let jsonText = String(data: jsonData, encoding: .utf8) ?? "[]"

        return """
        Translate each item into \(targetLanguage).
        Return ONLY a JSON array of strings with exactly \(texts.count) elements, same order as input indexes.
        Do not include markdown fences, keys, or explanations.
        \(glossaryHint)

        Input:
        \(jsonText)
        """
    }

    static func parse(response: String, expectedCount: Int) throws -> [String] {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BatchTranslationParseError.emptyResponse }

        if let jsonTranslations = tryParseJSONArray(from: trimmed) {
            guard jsonTranslations.count == expectedCount else {
                throw BatchTranslationParseError.countMismatch(expected: expectedCount, actual: jsonTranslations.count)
            }
            return jsonTranslations
        }

        // Legacy delimiter protocol (no empty-filter to avoid silent shifts)
        let separator = "|||"
        if trimmed.contains(separator) {
            let parts = trimmed
                .components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == expectedCount else {
                throw BatchTranslationParseError.countMismatch(expected: expectedCount, actual: parts.count)
            }
            return parts
        }

        if expectedCount == 1 {
            return [trimmed]
        }

        throw BatchTranslationParseError.invalidJSON
    }

    private static func tryParseJSONArray(from response: String) -> [String]? {
        let candidates = [response, extractJSONArray(from: response)].compactMap { $0 }
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                let strings = array.map { value -> String in
                    if let string = value as? String { return string }
                    if let number = value as? NSNumber { return number.stringValue }
                    return String(describing: value)
                }
                return strings
            }
        }
        return nil
    }

    private static func extractJSONArray(from text: String) -> String? {
        var working = text
        if working.hasPrefix("```") {
            working = working
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = working.firstIndex(of: "["),
              let end = working.lastIndex(of: "]"),
              start < end else {
            return nil
        }
        return String(working[start...end])
    }
}
