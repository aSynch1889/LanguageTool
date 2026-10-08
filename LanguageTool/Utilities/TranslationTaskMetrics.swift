import Foundation

struct TranslationTaskMetrics: Equatable {
    var totalTexts: Int = 0
    var cacheHits: Int = 0
    var networkTranslations: Int = 0
    var fallbackCount: Int = 0
    var durationSeconds: Double = 0
    var providerId: String = ""
    var routeReason: String = ""
    var fallbackPath: [String] = []

    var summaryLine: String {
        var parts = [
            "texts=\(totalTexts)",
            "cache=\(cacheHits)",
            "network=\(networkTranslations)",
            "fallback=\(fallbackCount)",
            String(format: "duration=%.2fs", durationSeconds)
        ]
        if !providerId.isEmpty {
            parts.append("provider=\(providerId)")
        }
        if !routeReason.isEmpty {
            parts.append("route=\(routeReason)")
        }
        return parts.joined(separator: " ")
    }

    mutating func recordFallback(from: String, to: String) {
        fallbackCount += 1
        fallbackPath.append("\(from)→\(to)")
    }
}
