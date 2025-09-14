import Foundation

// MARK: - GLM Request Builder

struct GLMRequestBuilder: RequestBuilder {
    func buildRequest(messages: [Message], translationOptions: [String: String]?) -> [String: Any] {
        var requestBody: [String: Any] = [
            "model": "glm-4.5",
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content
            ]},
            "temperature": 0.7,
            "max_tokens": 4096
        ]

        // GLM支持思考模式，对翻译任务很有用
        requestBody["thinking"] = [
            "type": "enabled"
        ]

        return requestBody
    }
}

// MARK: - GLM Response Parser

struct GLMResponseParser: ResponseParser {
    func parseResponse(data: Data) throws -> String {
        let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // 检查错误响应
        if let error = jsonDict?["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            let code = error["code"] as? String ?? ""

            // GLM特定错误处理
            if code.contains("rate_limit") || message.contains("rate limit") {
                throw AIError.rateLimitExceeded
            } else if code.contains("invalid_api_key") || message.contains("API key") {
                throw AIError.unauthorized
            } else if code.contains("quota") || message.contains("quota") {
                throw AIError.rateLimitExceeded
            }
            throw AIError.apiError("GLM Error [\(code)]: \(message)")
        }

        // 解析正常响应 (OpenAI兼容格式)
        if let choices = jsonDict?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 检查是否有thinking内容需要排除
        if let choices = jsonDict?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw AIError.invalidResponse
    }
}