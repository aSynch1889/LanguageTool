import Foundation

// MARK: - Kimi Request Builder

struct KimiRequestBuilder: RequestBuilder {
    func buildRequest(messages: [Message], translationOptions: [String: String]?) -> [String: Any] {
        return [
            "model": "moonshot-v1-8k",  // Kimi 的默认模型
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content
            ]},
            "temperature": 0.7,
            "max_tokens": 2048
        ]
    }
}

// MARK: - Kimi Response Parser

struct KimiResponseParser: ResponseParser {
    func parseResponse(data: Data) throws -> String {
        let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // 检查错误响应
        if let error = jsonDict?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("rate limit") || message.contains("quota") {
                throw AIError.rateLimitExceeded
            } else if message.contains("invalid") && message.contains("key") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }

        // 解析正常响应 (OpenAI兼容格式)
        if let choices = jsonDict?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw AIError.invalidResponse
    }
}