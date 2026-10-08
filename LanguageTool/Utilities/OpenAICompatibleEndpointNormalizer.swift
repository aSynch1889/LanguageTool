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

    static func suggestedModel(forBaseURL raw: String) -> String? {
        let lower = raw.lowercased()
        if lower.contains("api.deepseek.com") {
            return "deepseek-flash"
        }
        if lower.contains("api.moonshot.cn") {
            return "moonshot-v1-8k"
        }
        if lower.contains("open.bigmodel.cn") {
            return "glm-4.5"
        }
        if lower.contains("openrouter.ai") {
            return "openai/gpt-4o-mini"
        }
        if lower.contains("api.openai.com") {
            return "gpt-4o-mini"
        }
        if lower.contains("dashscope.aliyuncs.com") {
            return "qwen-mt-turbo"
        }
        return nil
    }
}
