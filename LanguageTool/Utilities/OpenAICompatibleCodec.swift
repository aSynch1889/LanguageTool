import Foundation

enum OpenAICompatibleParseError: Error, Equatable {
    case rateLimitExceeded
    case unauthorized
    case apiError(String)
    case invalidResponse
}

struct OpenAICompatibleRequestOptions: Equatable {
    var temperature: Double?
    var maxTokens: Int?
    var enableThinking: Bool
    var supportsTranslationOptions: Bool

    static let standard = OpenAICompatibleRequestOptions(
        temperature: nil,
        maxTokens: nil,
        enableThinking: false,
        supportsTranslationOptions: false
    )
}

enum OpenAICompatibleContentExtraction: Equatable {
    case trim
    case aliyunTrailingSegment
}

enum OpenAICompatibleCodec {
    struct Message: Equatable {
        let role: String
        let content: String
    }

    static func buildRequest(
        messages: [Message],
        model: String,
        options: OpenAICompatibleRequestOptions,
        translationOptions: [String: String]? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content
            ]}
        ]

        if let temperature = options.temperature {
            body["temperature"] = temperature
        }
        if let maxTokens = options.maxTokens {
            body["max_tokens"] = maxTokens
        }
        if options.enableThinking {
            body["thinking"] = ["type": "enabled"]
        }
        if options.supportsTranslationOptions, let translationOptions {
            body["translation_options"] = [
                "source_lang": translationOptions["source_lang"] ?? "auto",
                "target_lang": translationOptions["target_lang"] ?? "English"
            ]
        }

        return body
    }

    static func parseContent(
        _ data: Data,
        extraction: OpenAICompatibleContentExtraction
    ) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any] {
            let message = (error["message"] as? String ?? "Unknown error").lowercased()
            let code = (error["code"] as? String ?? "").lowercased()
            if code.contains("rate_limit") || message.contains("rate limit") || message.contains("quota") {
                throw OpenAICompatibleParseError.rateLimitExceeded
            }
            if code.contains("invalid_api_key")
                || (message.contains("invalid") && message.contains("key"))
                || message.contains("unauthorized")
                || message.contains("api key") {
                throw OpenAICompatibleParseError.unauthorized
            }
            throw OpenAICompatibleParseError.apiError(error["message"] as? String ?? "Unknown error")
        }

        var raw: String?
        if let choices = json?["choices"] as? [[String: Any]],
           let first = choices.first {
            if let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                raw = content
            } else if let delta = first["delta"] as? [String: Any],
                      let content = delta["content"] as? String {
                raw = content
            }
        }

        guard var content = raw else {
            throw OpenAICompatibleParseError.invalidResponse
        }

        switch extraction {
        case .trim:
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        case .aliyunTrailingSegment:
            if let range = content.range(of: "\n\n", options: .backwards) {
                content = String(content[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return content
    }
}
