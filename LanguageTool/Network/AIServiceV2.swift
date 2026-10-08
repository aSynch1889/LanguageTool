import Foundation

// MARK: - AI Service V2 - New Architecture

struct TranslationStatistics {
    let totalTexts: Int
    let existingTranslations: Int
    let newTranslations: Int
    let skippedTranslations: Int

    var summary: String {
        if skippedTranslations > 0 {
            return "Successfully translated \(newTranslations) new items, skipped \(skippedTranslations) existing translations".localized
        } else {
            return "Successfully translated \(newTranslations) items".localized
        }
    }
}

class AIServiceV2 {
    static let shared = AIServiceV2()

    private let networkClient: NetworkClientProtocol
    private let providerManager: AIProviderManager
    private let providerRegistry: AIProviderRegistry
    let chunkSize: Int

    init(networkClient: NetworkClientProtocol = NetworkClient.shared,
         providerManager: AIProviderManager = AIProviderManager.shared,
         providerRegistry: AIProviderRegistry = AIProviderRegistry.shared,
         chunkSize: Int = BatchTranslationParser.defaultChunkSize) {
        self.networkClient = networkClient
        self.providerManager = providerManager
        self.providerRegistry = providerRegistry
        self.chunkSize = chunkSize
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

        return try await executeRequestWithFallback(
            provider: provider,
            apiKey: apiKey,
            messages: messages
        )
    }

    func translate(text: String, to targetLanguage: String) async throws -> String {
        let message = Message(role: "system",
                            content: "将以下文本翻译成\(targetLanguage)语言，只需要返回翻译结果，不需要任何解释：\n\(text)")

        return try await sendMessage(messages: [message])
    }

    func batchTranslate(texts: [String], to targetLanguage: String) async throws -> [String] {
        guard !texts.isEmpty else { return [] }

        guard let provider = providerManager.getSelectedProvider() else {
            throw AIError.invalidConfiguration("No AI provider selected")
        }

        let apiKey = providerManager.getApiKey(for: provider.id)
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration("API key not configured for \(provider.name)")
        }

        let glossaryHint = glossaryPromptHint()
        let translationOptions = provider.id == "aliyun" ? [
            "source_lang": "auto",
            "target_lang": targetLanguage
        ] : nil

        var allTranslations: [String] = []
        for chunk in BatchTranslationParser.chunk(texts, size: chunkSize) {
            try Task.checkCancellation()

            let prompt = BatchTranslationParser.buildPrompt(
                texts: chunk,
                targetLanguage: targetLanguage,
                glossaryHint: glossaryHint
            )
            let messages = [Message(role: "user", content: prompt)]
            let response = try await executeRequestWithFallback(
                provider: provider,
                apiKey: apiKey,
                messages: messages,
                translationOptions: translationOptions
            )

            do {
                let parsed = try BatchTranslationParser.parse(response: response, expectedCount: chunk.count)
                allTranslations.append(contentsOf: parsed)
            } catch {
                throw AIError.invalidResponse
            }
        }

        guard allTranslations.count == texts.count else {
            throw AIError.invalidResponse
        }
        return allTranslations
    }

    func batchTranslateWithExisting(texts: [String],
                                  to targetLanguage: String,
                                  existingTranslations: [String?],
                                  skipExisting: Bool = true) async throws -> (translations: [String], statistics: TranslationStatistics) {

        guard texts.count == existingTranslations.count else {
            throw AIError.invalidConfiguration("Texts and existing translations arrays must have same length")
        }

        if !skipExisting {
            let allTranslations = try await batchTranslate(texts: texts, to: targetLanguage)
            let statistics = TranslationStatistics(
                totalTexts: texts.count,
                existingTranslations: 0,
                newTranslations: allTranslations.count,
                skippedTranslations: 0
            )
            return (allTranslations, statistics)
        }

        var result: [String] = []
        var textsToTranslate: [String] = []
        var indicesToTranslate: [Int] = []
        var skippedCount = 0

        for (index, text) in texts.enumerated() {
            if let existingTranslation = existingTranslations[index], !existingTranslation.isEmpty {
                result.append(existingTranslation)
                skippedCount += 1
            } else {
                result.append("")
                textsToTranslate.append(text)
                indicesToTranslate.append(index)
            }
        }

        var newTranslationsCount = 0
        if !textsToTranslate.isEmpty {
            let newTranslations = try await batchTranslate(texts: textsToTranslate, to: targetLanguage)
            newTranslationsCount = newTranslations.count

            for (translationIndex, resultIndex) in indicesToTranslate.enumerated() {
                if translationIndex < newTranslations.count {
                    result[resultIndex] = newTranslations[translationIndex]
                }
            }
        }

        let statistics = TranslationStatistics(
            totalTexts: texts.count,
            existingTranslations: skippedCount,
            newTranslations: newTranslationsCount,
            skippedTranslations: skippedCount
        )

        return (result, statistics)
    }

    /// Sends a minimal request to verify API key / endpoint / model for the selected provider.
    func testConnection() async throws -> String {
        guard let provider = providerManager.getSelectedProvider() else {
            throw AIError.invalidConfiguration("No AI provider selected")
        }

        let apiKey = providerManager.getApiKey(for: provider.id)
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration("API key not configured for \(provider.name)")
        }

        if provider.requiresCustomEndpoint {
            let baseURL = providerManager.effectiveBaseURL(for: provider)
            guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIError.invalidConfiguration("Base URL is required for OpenAI Compatible provider")
            }
        }

        let messages = [
            Message(role: "user", content: "Reply with exactly: ok")
        ]
        let reply = try await executeRequest(
            provider: provider,
            apiKey: apiKey,
            messages: messages
        )
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Implementation

    private func executeRequest(provider: AIProviderConfig,
                              apiKey: String,
                              messages: [Message],
                              translationOptions: [String: String]? = nil) async throws -> String {

        let model = providerManager.effectiveModel(for: provider)
        let requestBody = provider.requestBuilder.buildRequest(
            messages: messages,
            model: model,
            translationOptions: translationOptions
        )

        let httpConfig = try buildHTTPConfig(
            provider: provider,
            apiKey: apiKey,
            model: model,
            requestBody: requestBody
        )

        let responseData = try await networkClient.execute(config: httpConfig)

        return try provider.responseParser.parseResponse(data: responseData)
    }

    private func executeRequestWithFallback(provider: AIProviderConfig,
                                          apiKey: String,
                                          messages: [Message],
                                          translationOptions: [String: String]? = nil) async throws -> String {
        do {
            return try await executeRequest(
                provider: provider,
                apiKey: apiKey,
                messages: messages,
                translationOptions: translationOptions
            )
        } catch {
            guard let fallbackProvider = providerManager.getFallbackProvider(),
                  fallbackProvider.id != provider.id else {
                throw error
            }

            let fallbackApiKey = providerManager.getApiKey(for: fallbackProvider.id)
            guard !fallbackApiKey.isEmpty else {
                throw error
            }

            print("Primary provider failed, trying fallback provider: \(fallbackProvider.displayName)")
            return try await executeRequest(
                provider: fallbackProvider,
                apiKey: fallbackApiKey,
                messages: messages,
                translationOptions: translationOptions
            )
        }
    }

    private func buildHTTPConfig(provider: AIProviderConfig,
                               apiKey: String,
                               model: String,
                               requestBody: [String: Any]) throws -> HTTPRequestConfig {

        let baseURL = providerManager.effectiveBaseURL(for: provider)
        var urlString = baseURL.replacingOccurrences(of: "{model}", with: model)
        var headers = ["Content-Type": "application/json"]

        switch provider.authType {
        case .bearer(token: _):
            headers["Authorization"] = "Bearer \(apiKey)"
        case .apiKey(key: _, location: let location):
            switch location {
            case .header(name: let headerName):
                headers[headerName] = apiKey
            case .queryParameter(name: let paramName):
                let encoded = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
                urlString += urlString.contains("?") ? "&" : "?"
                urlString += "\(paramName)=\(encoded)"
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

    private func glossaryPromptHint() -> String {
        GlossaryStore.promptHint(from: GlossaryStore.loadRaw())
    }
}
