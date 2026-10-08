import Foundation

enum PlaceholderValidator {
    /// Extracts common localization placeholders: %@, %d, %ld, %1$@, {name}, {{name}}, ICU `{count, plural, ...}` heads.
    static func extract(_ text: String) -> [String] {
        var found: [String] = []

        let printfPattern = #"%(\d+\$)?[@dDifFsSxX]|%ld|%lu"#
        if let regex = try? NSRegularExpression(pattern: printfPattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                if let swiftRange = Range(match.range, in: text) {
                    found.append(String(text[swiftRange]))
                }
            }
        }

        let bracePattern = #"\{[^{}]+\}"#
        if let regex = try? NSRegularExpression(pattern: bracePattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                if let swiftRange = Range(match.range, in: text) {
                    found.append(String(text[swiftRange]))
                }
            }
        }

        let doubleBracePattern = #"\{\{[^{}]+\}\}"#
        if let regex = try? NSRegularExpression(pattern: doubleBracePattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                if let swiftRange = Range(match.range, in: text) {
                    found.append(String(text[swiftRange]))
                }
            }
        }

        return found.sorted()
    }

    static func validate(source: String, translation: String) -> [String] {
        let sourceTokens = extract(source)
        let translationTokens = extract(translation)
        guard sourceTokens != translationTokens else { return [] }

        var issues: [String] = []
        let sourceCounts = Dictionary(grouping: sourceTokens, by: { $0 }).mapValues(\.count)
        let translationCounts = Dictionary(grouping: translationTokens, by: { $0 }).mapValues(\.count)

        for (token, count) in sourceCounts {
            let actual = translationCounts[token] ?? 0
            if actual != count {
                issues.append("Placeholder \(token) expected \(count), found \(actual)")
            }
        }
        for (token, count) in translationCounts where sourceCounts[token] == nil {
            issues.append("Unexpected placeholder \(token) x\(count)")
        }
        return issues
    }
}
