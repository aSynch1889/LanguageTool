import Foundation

/// Canonical default AI providers after streamlining the picker.
enum ProviderCatalog {
    static let defaultProviderIds: [String] = [
        "aliyun",
        "gemini",
        "openai_compatible",
        "openrouter"
    ]

    static let fallbackDefaultProviderId = "openai_compatible"

    /// Maps removed first-class providers (and empty) onto the streamlined catalog.
    static func migrateProviderId(_ providerId: String) -> String {
        let trimmed = providerId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallbackDefaultProviderId }
        if defaultProviderIds.contains(trimmed) { return trimmed }
        switch trimmed {
        case "deepseek", "kimi", "glm":
            return fallbackDefaultProviderId
        default:
            return fallbackDefaultProviderId
        }
    }

    /// Hints so users can recreate former presets via OpenAI Compatible.
    static func legacyEndpointHint(for providerId: String) -> (baseURL: String, model: String)? {
        switch providerId {
        case "deepseek":
            return ("https://api.deepseek.com/chat/completions", "deepseek-flash")
        case "kimi":
            return ("https://api.moonshot.cn/v1/chat/completions", "moonshot-v1-8k")
        case "glm":
            return ("https://open.bigmodel.cn/api/paas/v4/chat/completions", "glm-4.5")
        default:
            return nil
        }
    }
}
