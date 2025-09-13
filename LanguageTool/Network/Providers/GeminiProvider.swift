import Foundation

// MARK: - Gemini Request Builder

struct GeminiRequestBuilder: RequestBuilder {
    func buildRequest(messages: [Message], translationOptions: [String: String]?) -> [String: Any] {
        return [
            "contents": [
                [
                    "parts": [
                        [
                            "text": messages.last?.content ?? ""
                        ]
                    ]
                ]
            ]
        ]
    }
}

// MARK: - Gemini Response Parser

struct GeminiResponseParser: ResponseParser {
    func parseResponse(data: Data) throws -> String {
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check for error response
        if let error = jsonResponse?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("quota") {
                throw AIError.rateLimitExceeded
            } else if message.contains("API key") || message.contains("authentication") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }

        // Parse successful response
        if let candidates = jsonResponse?["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text
        }
        throw AIError.invalidResponse
    }
}