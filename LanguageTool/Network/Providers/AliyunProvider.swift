import Foundation

// MARK: - Aliyun Request Builder

struct AliyunRequestBuilder: RequestBuilder {
    func buildRequest(messages: [Message], translationOptions: [String: String]?) -> [String: Any] {
        var body: [String: Any] = [
            "model": "qwen-mt-turbo",
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content
            ]}
        ]

        if let options = translationOptions {
            body["translation_options"] = [
                "source_lang": options["source_lang"] ?? "auto",
                "target_lang": options["target_lang"] ?? "English"
            ]
        }

        return body
    }
}

// MARK: - Aliyun Response Parser

struct AliyunResponseParser: ResponseParser {
    func parseResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check for error response
        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("rate limit") {
                throw AIError.rateLimitExceeded
            } else if message.contains("invalid api key") || message.contains("unauthorized") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }

        // Parse successful response
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        // Extract translation result from content (same logic as original)
        if let lastNewlineRange = content.range(of: "\n\n", options: .backwards) {
            let translationResult = content[lastNewlineRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return translationResult
        }

        return content
    }
}