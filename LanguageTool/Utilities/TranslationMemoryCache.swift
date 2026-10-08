import Foundation
import CryptoKit

struct TranslationMemoryCache {
    private var storage: [String: String] = [:]

    static func makeKey(source: String, targetLanguage: String, glossaryFingerprint: String) -> String {
        let payload = "\(targetLanguage)\u{1f}\(glossaryFingerprint)\u{1f}\(source)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func glossaryFingerprint(from rawGlossary: String) -> String {
        let entries = GlossaryStore.parse(rawGlossary)
            .map { "\($0.source)=\($0.target)" }
            .sorted()
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(entries.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func get(_ key: String) -> String? {
        storage[key]
    }

    mutating func set(_ value: String, for key: String) {
        storage[key] = value
    }

    mutating func storeBatch(
        texts: [String],
        translations: [String],
        targetLanguage: String,
        glossaryFingerprint: String
    ) {
        guard texts.count == translations.count else { return }
        for (text, translation) in zip(texts, translations) {
            let key = Self.makeKey(
                source: text,
                targetLanguage: targetLanguage,
                glossaryFingerprint: glossaryFingerprint
            )
            set(translation, for: key)
        }
    }

    func resolveBatch(
        texts: [String],
        targetLanguage: String,
        glossaryFingerprint: String
    ) -> (resolved: [String?], missingIndices: [Int]) {
        var resolved: [String?] = Array(repeating: nil, count: texts.count)
        var missing: [Int] = []
        for (index, text) in texts.enumerated() {
            let key = Self.makeKey(
                source: text,
                targetLanguage: targetLanguage,
                glossaryFingerprint: glossaryFingerprint
            )
            if let hit = get(key) {
                resolved[index] = hit
            } else {
                missing.append(index)
            }
        }
        return (resolved, missing)
    }
}
