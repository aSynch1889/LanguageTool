import Foundation

struct TranslationItem: Identifiable, Sendable, Equatable {
    /// Stable identity for table selection / dirty tracking.
    var id: String { key }

    var isSelected: Bool
    var key: String
    var translations: [String: String]
    var comment: String

    init(
        isSelected: Bool = true,
        key: String,
        translations: [String: String] = [:],
        comment: String = ""
    ) {
        self.isSelected = isSelected
        self.key = key
        self.translations = translations
        self.comment = comment
    }
}
