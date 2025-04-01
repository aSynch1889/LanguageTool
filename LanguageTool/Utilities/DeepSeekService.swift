import SwiftUI

struct DeepSeekService: AIServiceProtocol {
    var baseURL: String {
        return "https://api.deepseek.com/v1/chat/completions"
    }
    
    func buildRequestBody(messages: [Message], translationOptions: [String: String]? = nil) -> [String: Any] {
        return [
            "model": "deepseek-chat",
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
    }
    
    func parseResponse(data: Data) throws -> String {
        let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // 检查错误响应
        if let error = jsonDict?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("rate limit") {
                throw AIError.rateLimitExceeded
            } else if message.contains("invalid api key") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }
        
        // 解析正常响应
        if let choices = jsonDict?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        throw AIError.invalidResponse
    }
}
