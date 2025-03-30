import Foundation

class AliyunService: AIServiceProtocol {
    var baseURL: String {
        return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    }
    
    func buildRequestBody(messages: [Message]) -> [String: Any] {
        return [
            "model": "qwen-mt-turbo",
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content
            ]},
            "translation_options": [
                "source_lang": "auto",
                "target_lang": "English"
            ]
        ]
    }
    
    func parseResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidData
        }
        
        return content
    }
} 