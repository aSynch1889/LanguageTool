import Foundation

struct GlossaryEntry: Equatable, Identifiable {
    let id: String
    let source: String
    let target: String

    init(source: String, target: String) {
        self.source = source
        self.target = target
        self.id = "\(source)=\(target)"
    }
}

enum GlossaryStore {
    static let storageKey = "translationGlossary"
    static let maxEntries = 200
    static let maxLineLength = 200

    static func loadRaw(from defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: storageKey) ?? ""
    }

    static func saveRaw(_ raw: String, to defaults: UserDefaults = .standard) {
        defaults.set(raw, forKey: storageKey)
    }

    /// Parses lines like `iPhone => iPhone` or `Foo=Bar`. Drops invalid/oversized lines.
    static func parse(_ raw: String) -> [GlossaryEntry] {
        var entries: [GlossaryEntry] = []
        var seen = Set<String>()

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard trimmed.count <= maxLineLength else { continue }

            let parts: [String]
            if trimmed.contains("=>") {
                parts = trimmed.components(separatedBy: "=>")
            } else if trimmed.contains("=") {
                parts = trimmed.components(separatedBy: "=")
            } else {
                continue
            }

            guard parts.count >= 2 else { continue }
            let source = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let target = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !target.isEmpty else { continue }
            guard !seen.contains(source) else { continue }

            seen.insert(source)
            entries.append(GlossaryEntry(source: source, target: target))
            if entries.count >= maxEntries { break }
        }

        return entries
    }

    static func promptHint(from raw: String) -> String {
        let entries = parse(raw)
        guard !entries.isEmpty else { return "" }
        let lines = entries.map { "\($0.source) => \($0.target)" }.joined(separator: "\n")
        return """

        Strict glossary (do not translate left side; use right side as target wording):
        \(lines)
        """
    }

    static func validate(_ raw: String) -> (entries: [GlossaryEntry], droppedLines: Int) {
        let allNonEmpty = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .count
        let entries = parse(raw)
        return (entries, max(0, allNonEmpty - entries.count))
    }
}
