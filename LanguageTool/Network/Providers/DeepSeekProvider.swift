import Foundation

// MARK: - DeepSeek Request Builder

struct DeepSeekRequestBuilder: RequestBuilder {
    func buildRequest(messages: [Message], translationOptions: [String: String]?) -> [String: Any] {
        return [
            "model": "deepseek-chat",
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content
            ]}
        ]
    }
}

// MARK: - DeepSeek Response Parser

struct DeepSeekResponseParser: ResponseParser {
    func parseResponse(data: Data) throws -> String {
        let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check for error response
        if let error = jsonDict?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("rate limit") {
                throw AIError.rateLimitExceeded
            } else if message.contains("invalid api key") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }

        // Parse successful response
        if let choices = jsonDict?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        throw AIError.invalidResponse
    }
}