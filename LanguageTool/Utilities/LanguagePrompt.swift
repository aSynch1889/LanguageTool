import Foundation

enum LanguagePrompt {
    /// Stable label for AI prompts: `ja (Japanese)`.
    static func label(for code: String) -> String {
        if let language = Language.supportedLanguages.first(where: { $0.code == code }) {
            return "\(code) (\(language.name))"
        }
        return code
    }
}
