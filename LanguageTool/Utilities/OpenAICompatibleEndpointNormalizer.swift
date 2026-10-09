import Foundation

/// Normalizes OpenAI-compatible endpoint fields.
/// Docs often show SDK `base_url` as a host/root (e.g. `https://api.deepseek.com`),
/// while this app POSTs directly to the chat completions path.
enum OpenAICompatibleEndpointNormalizer {
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        guard !value.isEmpty else { return value }

        let lower = value.lowercased()
        if lower.hasSuffix("/chat/completions") {
            return value
        }
        return value + "/chat/completions"
    }

    /// Preset chat models for a known vendor host. First item is the preferred default.
    static func suggestedModels(forBaseURL raw: String) -> [String] {
        let lower = raw.lowercased()
        if lower.contains("api.deepseek.com") {
            return ["deepseek-flash", "deepseek-chat", "deepseek-reasoner"]
        }
        if lower.contains("api.moonshot.cn") {
            return ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]
        }
        if lower.contains("open.bigmodel.cn") {
            return ["glm-4.5", "glm-4-flash", "glm-4-plus"]
        }
        if lower.contains("openrouter.ai") {
            return [
                "openai/gpt-4o-mini",
                "openai/gpt-4o",
                "anthropic/claude-3.5-sonnet",
                "google/gemini-2.0-flash-001"
            ]
        }
        if lower.contains("api.openai.com") {
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "gpt-4.1"]
        }
        if lower.contains("dashscope.aliyuncs.com") {
            return ["qwen-mt-turbo", "qwen-turbo", "qwen-plus", "qwen-max"]
        }
        if lower.contains("generativelanguage.googleapis.com") {
            return ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash"]
        }
        return []
    }

    static func suggestedModel(forBaseURL raw: String) -> String? {
        suggestedModels(forBaseURL: raw).first
    }
}
