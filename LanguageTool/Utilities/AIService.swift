import Foundation
import SwiftUI

protocol AIServiceProtocol {
    var baseURL: String { get }
    func buildRequestBody(messages: [Message]) -> [String: Any]
    func parseResponse(data: Data) throws -> String
}

struct Message: Codable {
    let role: String
    let content: String
}

class AIService {
    static let shared = AIService()
    
    @AppStorage("selectedAIService") private var selectedService: AIServiceType = .deepseek
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("aliyunApiKey") private var aliyunApiKey: String = ""
    
    private var apiKey: String {
        AppSettings.shared.apiKey
    }
    
    enum AIError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case jsonError(Error)
        case invalidConfiguration(String)
        
        var localizedDescription: String {
            switch self {
            case .invalidConfiguration(let message):
                return "⚠️ 配置错误: \(message)"
            case .invalidURL:
                return "❌ URL 创建失败"
            case .networkError(let error):
                return "❌ 网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "⚠️ 无效的响应"
            case .jsonError(let error):
                return "❌ JSON 错误: \(error.localizedDescription)"
            }
        }
    }
    
    func sendMessage(messages: [Message], completion: @escaping (Result<String, AIError>) -> Void) {
        let service: AIServiceProtocol
        
        switch selectedService {
        case .deepseek:
            service = DeepSeekService()
        case .gemini:
            service = GeminiService()
        case .aliyun:
            service = AliyunService()
        }
        
        sendMessage(messages: messages, service: service, completion: completion)
    }
    
    func translate(text: String, to targetLanguage: String) async throws -> String {
        switch selectedService {
        case .deepseek:
            return try await translateWithDeepseek(text: text, to: targetLanguage)
        case .gemini:
            return try await translateWithGemini(text: text, to: targetLanguage)
        case .aliyun:
            return try await makeAliyunRequest(prompt: text)
        }
    }
    
    /// 批量翻译文本
    func batchTranslate(texts: [String], to targetLanguage: String) async throws -> [String] {
        // 将所有文本合并成一个字符串，使用特殊分隔符
        let separator = "|||"
        let combinedText = texts.joined(separator: separator)
        
        // 生成翻译提示
        let prompt = """
        请将以下文本翻译成\(targetLanguage)。
        每个文本之间使用 ||| 分隔，请保持这个分隔符，只返回翻译结果：
        
        \(combinedText)
        """
        
        let messages = [Message(role: "user", content: prompt)]
        
        // 发送翻译请求
        let response = try await withCheckedThrowingContinuation { continuation in
            sendMessage(messages: messages) { result in
                switch result {
                case .success(let content):
                    continuation.resume(returning: content)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // 清理并分割翻译结果
        let cleanedResponse = response
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        
        let translations = cleanedResponse.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 确保翻译结果数量与原文本数量匹配
        guard translations.count == texts.count else {
            throw AIError.invalidResponse
        }
        
        return translations
    }
    
    /// 生成翻译提示
//    private func generateTranslationPrompt(texts: [String], targetLanguage: String) -> String {
//        let numberedTexts = texts.enumerated().map { index, text in
//            "\(index + 1). \(text)"
//        }.joined(separator: "\n")
//        
//        return """
//        请将以下文本翻译成\(targetLanguage)语言。
//        只需返回翻译结果，每行一个翻译，保持原有的编号顺序：
//        
//        \(numberedTexts)
//        """
//    }
    
    /// 解析翻译结果
//    private func parseTranslations(from response: String) -> [String] {
//        // 移除可能的序号和额外标记
//        let lines = response
//            .components(separatedBy: .newlines)
//            .map { line -> String in
//                var cleaned = line
//                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
//                    .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
//                    .replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
//                
//                // 如果翻译文本被引号包围，移除引号
//                if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
//                    cleaned = String(cleaned.dropFirst().dropLast())
//                }
//                
//                return cleaned
//            }
//            .filter { !$0.isEmpty }
//        
//        return lines
//    }
    
    // 原有的 DeepSeek 翻译方法
    private func translateWithDeepseek(text: String, to targetLanguage: String) async throws -> String {
        let message = Message(role: "system",
                            content: "将以下文本翻译成\(targetLanguage)语言，只需要返回翻译结果，不需要任何解释：\n\(text)")
        
        return try await withCheckedThrowingContinuation { continuation in
            sendMessage(messages: [message]) { result in
                switch result {
                case .success(let translation):
                    continuation.resume(returning: translation.trimmingCharacters(in: .whitespacesAndNewlines))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 新增的 Gemini 翻译方法
    private func translateWithGemini(text: String, to targetLanguage: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(geminiApiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let prompt = "Translate the following text to \(targetLanguage). Only return the translation, no explanations: \(text)"
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = jsonResponse["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let translation = firstPart["text"] as? String {
            return translation
        }
        
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
    
    /// 测试 Gemini API 连接
//    func testGemini() async throws {
//        let apiKey = "YOUR_API_KEY"  // 替换为实际的 API key
//        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
//        let url = URL(string: urlString)!
//        
//        // 构建请求体
//        let requestBody: [String: Any] = [
//            "contents": [
//                [
//                    "parts": [
//                        [
//                            "text": "Hello, this is a test message."
//                        ]
//                    ]
//                ]
//            ]
//        ]
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
//        
//        print("开始测试 Gemini API...")
//        print("请求 URL: \(urlString)")
//        print("请求体: \(requestBody)")
//        
//        do {
//            let (data, response) = try await URLSession.shared.data(for: request)
//            
//            if let httpResponse = response as? HTTPURLResponse {
//                print("响应状态码: \(httpResponse.statusCode)")
//            }
//            
//            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
//                print("响应数据: \(jsonResponse)")
//            }
//            
//            print("API 测试成功")
//        } catch {
//            print("API 测试失败: \(error.localizedDescription)")
//            throw error
//        }
//    }
    
    private func getApiKey() -> String {
        var apiKeyToUse = ""
        switch selectedService {
        case .deepseek:
            apiKeyToUse = apiKey
        case .gemini:
            apiKeyToUse = geminiApiKey
        case .aliyun:
            apiKeyToUse = aliyunApiKey
        }
        return apiKeyToUse
    }

    private func makeAliyunRequest(prompt: String) async throws -> String {
        let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(aliyunApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "qwen-mt-turbo",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "translation_options": [
                "source_lang": "auto",
                "target_lang": "English"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidData
        }
        
        return content
    }
}


// 扩展 AIService 以实现协议
extension AIService {
    func sendMessage<T: AIServiceProtocol>(messages: [Message], service: T, completion: @escaping (Result<String, AIError>) -> Void) {
        let apiKeyToUse: String
        switch selectedService {
        case .deepseek:
            apiKeyToUse = apiKey
        case .gemini:
            apiKeyToUse = geminiApiKey
        case .aliyun:
            apiKeyToUse = aliyunApiKey
        }
        
        guard !apiKeyToUse.isEmpty else {
            completion(.failure(.invalidConfiguration("未设置 API Key")))
            return
        }
        
        print("🔑 使用的 API Key: \(apiKeyToUse)")  // 打印 API Key（注意：在生产环境中请勿打印敏感信息）
        
        let urlString: String
        switch selectedService {
        case .deepseek:
            urlString = service.baseURL
        case .gemini:
            urlString = service.baseURL + "?key=\(apiKeyToUse)"
        case .aliyun:
            urlString = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        // 打印完整的请求 URL
        print("🔗 请求的完整 URL: \(url.absoluteString)")
        print("📝 准备发送的消息内容: \(messages)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch selectedService {
        case .deepseek:
            request.setValue("Bearer \(apiKeyToUse)", forHTTPHeaderField: "Authorization")
        case .gemini:
            request.setValue("Bearer \(apiKeyToUse)", forHTTPHeaderField: "Authorization")
        case .aliyun:
            request.setValue("Bearer \(apiKeyToUse)", forHTTPHeaderField: "Authorization")
        default:
            print()
        }
        
        let body = service.buildRequestBody(messages: messages)
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(.jsonError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON 序列化失败"]))))
            return
        }
        
        request.httpBody = jsonData
        print("📤 发送请求体: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 网络错误: \(error.localizedDescription)")
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            print("📡 HTTP 状态码: \(httpResponse.statusCode)")  // 打印状态码
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ 无效的响应状态码: \(httpResponse.statusCode)")
                completion(.failure(.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            print("📥 收到响应数据: \(String(data: data, encoding: .utf8) ?? "")")
            
            do {
                let responseText = try service.parseResponse(data: data)
                DispatchQueue.main.async {
                    completion(.success(responseText))
                }
            } catch {
                print("❌ JSON 解析错误: \(error.localizedDescription)")
                completion(.failure(.jsonError(error)))
            }
        }
        
        task.resume()
    }
}
