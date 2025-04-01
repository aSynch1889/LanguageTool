import SwiftUI

struct GeminiService: AIServiceProtocol {
    var baseURL: String {
        return "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    }
    
    func buildRequestBody(messages: [Message], translationOptions: [String: String]? = nil) -> [String: Any] {
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
    
    func parseResponse(data: Data) throws -> String {
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // 检查错误响应
        if let error = jsonResponse?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("quota") {
                throw AIError.rateLimitExceeded
            } else if message.contains("API key") || message.contains("authentication") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }
        
        // 解析正常响应
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
