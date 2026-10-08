import Foundation

enum GlossaryEnforcer {
    static func validate(source: String, translation: String, entries: [GlossaryEntry]) -> [String] {
        var issues: [String] = []
        for entry in entries {
            guard source.localizedCaseInsensitiveContains(entry.source) else { continue }
            if !translation.contains(entry.target) {
                issues.append("Glossary term '\(entry.source)' should translate to '\(entry.target)'")
            }
        }
        return issues
    }

    /// Replaces leaked source terms with preferred glossary targets when present in the translation.
    static func applyPreferredTerms(source: String, translation: String, entries: [GlossaryEntry]) -> String {
        var result = translation
        for entry in entries {
            guard source.localizedCaseInsensitiveContains(entry.source) else { continue }
            if result.contains(entry.target) { continue }
            if result.localizedCaseInsensitiveContains(entry.source) {
                result = result.replacingOccurrences(
                    of: entry.source,
                    with: entry.target,
                    options: [.caseInsensitive]
                )
            }
        }
        return result
    }

    static func enforce(source: String, translation: String, entries: [GlossaryEntry]) -> String {
        applyPreferredTerms(source: source, translation: translation, entries: entries)
    }
}
