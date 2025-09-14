import Foundation

// MARK: - AI Service V2 - New Architecture

class AIServiceV2 {
    static let shared = AIServiceV2()

    private let networkClient: NetworkClientProtocol
    private let providerManager: AIProviderManager
    private let providerRegistry: AIProviderRegistry

    init(networkClient: NetworkClientProtocol = NetworkClient.shared,
         providerManager: AIProviderManager = AIProviderManager.shared,
         providerRegistry: AIProviderRegistry = AIProviderRegistry.shared) {
        self.networkClient = networkClient
        self.providerManager = providerManager
        self.providerRegistry = providerRegistry

        setupDefaultProviders()
    }

    // MARK: - Public Interface

    func sendMessage(messages: [Message], completion: @escaping (Result<String, AIError>) -> Void) {
        Task {
            do {
                let result = try await sendMessage(messages: messages)
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error as? AIError ?? AIError.networkError(error)))
                }
            }
        }
    }

    func sendMessage(messages: [Message]) async throws -> String {
        guard let provider = providerManager.getSelectedProvider() else {
            throw AIError.invalidConfiguration("No AI provider selected")
        }

        let apiKey = providerManager.getApiKey(for: provider.id)
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration("API key not configured for \(provider.name)")
        }

        return try await executeRequest(provider: provider, apiKey: apiKey, messages: messages)
    }

    func translate(text: String, to targetLanguage: String) async throws -> String {
        let message = Message(role: "system",
                            content: "将以下文本翻译成\(targetLanguage)语言，只需要返回翻译结果，不需要任何解释：\n\(text)")

        return try await sendMessage(messages: [message])
    }

    func batchTranslate(texts: [String], to targetLanguage: String) async throws -> [String] {
        let separator = "|||"
        let combinedText = texts.joined(separator: separator)

        let prompt = """
        请将以下文本翻译成\(targetLanguage)。
        每个文本之间使用 ||| 分隔，请保持这个分隔符，只返回翻译结果：

        \(combinedText)
        """

        let messages = [Message(role: "user", content: prompt)]

        guard let provider = providerManager.getSelectedProvider() else {
            throw AIError.invalidConfiguration("No AI provider selected")
        }

        let apiKey = providerManager.getApiKey(for: provider.id)
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration("API key not configured for \(provider.name)")
        }

        // Special handling for Aliyun with translation options
        let translationOptions = provider.id == "aliyun" ? [
            "source_lang": "auto",
            "target_lang": targetLanguage
        ] : nil

        let response = try await executeRequest(
            provider: provider,
            apiKey: apiKey,
            messages: messages,
            translationOptions: translationOptions
        )

        return try parseBatchTranslationResponse(response: response, separator: separator, expectedCount: texts.count)
    }

    // MARK: - Private Implementation

    private func executeRequest(provider: AIProviderConfig,
                              apiKey: String,
                              messages: [Message],
                              translationOptions: [String: String]? = nil) async throws -> String {

        let requestBody = provider.requestBuilder.buildRequest(messages: messages, translationOptions: translationOptions)

        let httpConfig = try buildHTTPConfig(provider: provider, apiKey: apiKey, requestBody: requestBody)

        let responseData = try await networkClient.execute(config: httpConfig)

        return try provider.responseParser.parseResponse(data: responseData)
    }

    private func buildHTTPConfig(provider: AIProviderConfig,
                               apiKey: String,
                               requestBody: [String: Any]) throws -> HTTPRequestConfig {

        var urlString = provider.baseURL
        var headers = ["Content-Type": "application/json"]

        // Handle authentication
        switch provider.authType {
        case .bearer(token: _):
            headers["Authorization"] = "Bearer \(apiKey)"
        case .apiKey(key: _, location: let location):
            switch location {
            case .header(name: let headerName):
                headers[headerName] = apiKey
            case .queryParameter(name: let paramName):
                urlString += urlString.contains("?") ? "&" : "?"
                urlString += "\(paramName)=\(apiKey)"
            }
        case .custom(headers: let customHeaders):
            for (key, value) in customHeaders {
                headers[key] = value.replacingOccurrences(of: "{API_KEY}", with: apiKey)
            }
        }

        guard let url = URL(string: urlString) else {
            throw AIError.invalidURL
        }

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        return HTTPRequestConfig(
            url: url,
            method: .post,
            headers: headers,
            body: bodyData
        )
    }

    private func parseBatchTranslationResponse(response: String, separator: String, expectedCount: Int) throws -> [String] {
        let cleanedResponse = response
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        let translations = cleanedResponse.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard translations.count == expectedCount else {
            throw AIError.invalidResponse
        }

        return translations
    }

    private func setupDefaultProviders() {
        // Register DeepSeek
        let deepseekConfig = AIProviderConfig(
            id: "deepseek",
            name: "deepseek",
            displayName: "DeepSeek Chat",
            baseURL: "https://api.deepseek.com/v1/chat/completions",
            model: "deepseek-chat",
            authType: .bearer(token: ""),
            requestBuilder: DeepSeekRequestBuilder(),
            responseParser: DeepSeekResponseParser()
        )
        providerRegistry.register(deepseekConfig)

        // Register Gemini
        let geminiConfig = AIProviderConfig(
            id: "gemini",
            name: "gemini",
            displayName: "Google Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent",
            model: "gemini-1.5-flash",
            authType: .apiKey(key: "", location: .queryParameter(name: "key")),
            requestBuilder: GeminiRequestBuilder(),
            responseParser: GeminiResponseParser()
        )
        providerRegistry.register(geminiConfig)

        // Register Aliyun
        let aliyunConfig = AIProviderConfig(
            id: "aliyun",
            name: "aliyun",
            displayName: "Aliyun",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
            model: "qwen-mt-turbo",
            authType: .bearer(token: ""),
            requestBuilder: AliyunRequestBuilder(),
            responseParser: AliyunResponseParser()
        )
        providerRegistry.register(aliyunConfig)

        // Register Kimi
        let kimiConfig = AIProviderConfig(
            id: "kimi",
            name: "kimi",
            displayName: "Kimi",
            baseURL: "https://api.moonshot.cn/v1/chat/completions",
            model: "moonshot-v1-8k",
            authType: .bearer(token: ""),
            requestBuilder: KimiRequestBuilder(),
            responseParser: KimiResponseParser()
        )
        providerRegistry.register(kimiConfig)

        // Register GLM
        let glmConfig = AIProviderConfig(
            id: "glm",
            name: "glm",
            displayName: "GLM-4.5",
            baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            model: "glm-4.5",
            authType: .bearer(token: ""),
            requestBuilder: GLMRequestBuilder(),
            responseParser: GLMResponseParser()
        )
        providerRegistry.register(glmConfig)
    }
}