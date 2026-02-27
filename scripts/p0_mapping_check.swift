import Foundation

@main
struct P0MappingCheck {
    static func main() throws {
        let sample: [String: Any] = [
            "sourceLanguage": "en",
            "version": "1.0",
            "strings": [
                "home.title": [
                    "localizations": [
                        "en": ["stringUnit": ["value": "Hello"]],
                        "fr": ["stringUnit": ["value": "Bonjour"]],
                    ],
                ],
                "profile.title": [
                    "localizations": [
                        "en": ["stringUnit": ["value": "Hello"]],
                        "de": ["stringUnit": ["value": "Hallo"]],
                    ],
                ],
            ],
        ]

        let fileURL = URL(fileURLWithPath: "/tmp/p0_mapping_input.xcstrings")
        let data = try JSONSerialization.data(withJSONObject: sample, options: [.prettyPrinted])
        try data.write(to: fileURL)

        guard let result = JsonUtils.extractValuesFromXCStrings(from: fileURL.path) else {
            fatalError("extractValuesFromXCStrings returned nil")
        }

        let keys = Set(result.entries.map { $0.key })
        if result.entries.count != 2 || !keys.contains("home.title") || !keys.contains("profile.title") {
            fatalError("mapping failed: entries=\(result.entries.map { $0.key })")
        }

        print("P0 mapping check passed")
    }
}
