import Foundation

class AliyunService: AIServiceProtocol {
    var baseURL: String {
        return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    }
    
    func buildRequestBody(messages: [Message], translationOptions: [String: String]? = nil) -> [String: Any] {
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
    
    func parseResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        // 寻找最后一个换行符后的内容
        if let lastNewlineRange = content.range(of: "\n\n", options: .backwards) {
            let translationResult = content[lastNewlineRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return translationResult
        }
        
        return content
    }
} 