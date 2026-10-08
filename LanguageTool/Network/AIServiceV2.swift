import Foundation

// MARK: - AI Service V2 - New Architecture

struct TranslationStatistics {
    let totalTexts: Int
    let existingTranslations: Int
    let newTranslations: Int
    let skippedTranslations: Int
    let cacheHits: Int
    let fallbackCount: Int
    let durationSeconds: Double
    let providerId: String

    init(
        totalTexts: Int,
        existingTranslations: Int,
        newTranslations: Int,
        skippedTranslations: Int,
        cacheHits: Int = 0,
        fallbackCount: Int = 0,
        durationSeconds: Double = 0,
        providerId: String = ""
    ) {
        self.totalTexts = totalTexts
        self.existingTranslations = existingTranslations
        self.newTranslations = newTranslations
        self.skippedTranslations = skippedTranslations
        self.cacheHits = cacheHits
        self.fallbackCount = fallbackCount
        self.durationSeconds = durationSeconds
        self.providerId = providerId
    }

    var summary: String {
        var base: String
        if skippedTranslations > 0 {
            base = "Successfully translated \(newTranslations) new items, skipped \(skippedTranslations) existing translations".localized
        } else {
            base = "Successfully translated \(newTranslations) items".localized
        }
        if cacheHits > 0 || fallbackCount > 0 || durationSeconds > 0 {
            base += " (\(String(format: "%.1fs", durationSeconds)), cache=\(cacheHits), fallback=\(fallbackCount))"
        }
        return base
    }
}

class AIServiceV2 {
    static let shared = AIServiceV2()

    private let networkClient: NetworkClientProtocol
    private let providerManager: AIProviderManager
    private let providerRegistry: AIProviderRegistry
    let chunkSize: Int
    private var translationMemory = TranslationMemoryCache()
    private(set) var lastTaskMetrics = TranslationTaskMetrics()
    private var activeTaskMetrics = TranslationTaskMetrics()

    init(networkClient: NetworkClientProtocol = NetworkClient.shared,
         providerManager: AIProviderManager = AIProviderManager.shared,
         providerRegistry: AIProviderRegistry = AIProviderRegistry.shared,
         chunkSize: Int = BatchTranslationParser.defaultChunkSize) {
        self.networkClient = networkClient
        self.providerManager = providerManager
        self.providerRegistry = providerRegistry
        self.chunkSize = chunkSize
    }

    /// Clears in-memory translation cache (useful after glossary changes).
    func clearTranslationMemory() {
        translationMemory = TranslationMemoryCache()
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

        let startedAt = Date()
        activeTaskMetrics = TranslationTaskMetrics()
        activeTaskMetrics.totalTexts = texts.count

        guard let selectedProvider = providerManager.getSelectedProvider() else {
            throw AIError.invalidConfiguration("No AI provider selected")
        }

        let glossaryRaw = GlossaryStore.loadRaw()
        let glossaryEntries = GlossaryStore.parse(glossaryRaw)
        let glossaryFingerprint = TranslationMemoryCache.glossaryFingerprint(from: glossaryRaw)
        let glossaryHint = GlossaryStore.promptHint(from: glossaryRaw)

        let (cachedResolved, missingIndices) = translationMemory.resolveBatch(
            texts: texts,
            targetLanguage: targetLanguage,
            glossaryFingerprint: glossaryFingerprint
        )

        var result: [String] = cachedResolved.map { $0 ?? "" }
        activeTaskMetrics.cacheHits = texts.count - missingIndices.count

        guard !missingIndices.isEmpty else {
            activeTaskMetrics.providerId = selectedProvider.id
            activeTaskMetrics.durationSeconds = Date().timeIntervalSince(startedAt)
            lastTaskMetrics = activeTaskMetrics
            print("Translation metrics: \(lastTaskMetrics.summaryLine)")
            return result
        }

        let textsToTranslate = missingIndices.map { texts[$0] }
        activeTaskMetrics.networkTranslations = textsToTranslate.count

        let mtAvailable = providerManager.hasValidApiKey(for: "aliyun")
            && providerRegistry.get("aliyun") != nil
        let route = TranslationRouter.decide(
            batchCount: textsToTranslate.count,
            primaryProviderId: selectedProvider.id,
            mtProviderId: "aliyun",
            mtAvailable: mtAvailable
        )

        let provider: AIProviderConfig
        if let routed = providerRegistry.get(route.preferredProviderId),
           providerManager.hasValidApiKey(for: routed.id) {
            provider = routed
            if route.reason == .largeBatchUsesMT {
                activeTaskMetrics.routeReason = "largeBatchUsesMT"
                print("Translation router: large batch → MT provider \(routed.displayName)")
            }
        } else {
            provider = selectedProvider
        }
        activeTaskMetrics.providerId = provider.id

        let apiKey = providerManager.getApiKey(for: provider.id)
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration("API key not configured for \(provider.name)")
        }

        let translationOptions = provider.id == "aliyun" ? [
            "source_lang": "auto",
            "target_lang": targetLanguage
        ] : nil

        var freshTranslations: [String] = []
        for chunk in BatchTranslationParser.chunk(textsToTranslate, size: chunkSize) {
            try Task.checkCancellation()
            let translatedChunk = try await translateChunkWithResilience(
                chunk: chunk,
                targetLanguage: targetLanguage,
                glossaryHint: glossaryHint,
                provider: provider,
                apiKey: apiKey,
                translationOptions: translationOptions,
                workingChunkSize: chunkSize
            )
            freshTranslations.append(contentsOf: translatedChunk)
        }

        guard freshTranslations.count == textsToTranslate.count else {
            throw AIError.invalidResponse
        }

        let qualityChecked = zip(textsToTranslate, freshTranslations).map { source, translation in
            postProcessTranslation(
                source: source,
                translation: translation,
                glossaryEntries: glossaryEntries
            )
        }

        translationMemory.storeBatch(
            texts: textsToTranslate,
            translations: qualityChecked,
            targetLanguage: targetLanguage,
            glossaryFingerprint: glossaryFingerprint
        )

        for (offset, index) in missingIndices.enumerated() {
            result[index] = qualityChecked[offset]
        }

        activeTaskMetrics.durationSeconds = Date().timeIntervalSince(startedAt)
        lastTaskMetrics = activeTaskMetrics
        print("Translation metrics: \(lastTaskMetrics.summaryLine)")
        return result
    }

    private func postProcessTranslation(
        source: String,
        translation: String,
        glossaryEntries: [GlossaryEntry]
    ) -> String {
        var output = GlossaryEnforcer.enforce(
            source: source,
            translation: translation,
            entries: glossaryEntries
        )
        let placeholderIssues = PlaceholderValidator.validate(source: source, translation: output)
        if !placeholderIssues.isEmpty {
            print("Placeholder validation: \(placeholderIssues.joined(separator: "; "))")
        }
        let glossaryIssues = GlossaryEnforcer.validate(
            source: source,
            translation: output,
            entries: glossaryEntries
        )
        if !glossaryIssues.isEmpty {
            print("Glossary validation: \(glossaryIssues.joined(separator: "; "))")
        }
        return output
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
            let metrics = lastTaskMetrics
            let statistics = TranslationStatistics(
                totalTexts: texts.count,
                existingTranslations: 0,
                newTranslations: allTranslations.count,
                skippedTranslations: 0,
                cacheHits: metrics.cacheHits,
                fallbackCount: metrics.fallbackCount,
                durationSeconds: metrics.durationSeconds,
                providerId: metrics.providerId
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

        let metrics = lastTaskMetrics
        let statistics = TranslationStatistics(
            totalTexts: texts.count,
            existingTranslations: skippedCount,
            newTranslations: newTranslationsCount,
            skippedTranslations: skippedCount,
            cacheHits: metrics.cacheHits,
            fallbackCount: metrics.fallbackCount,
            durationSeconds: metrics.durationSeconds,
            providerId: metrics.providerId
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

    private func translateChunkWithResilience(
        chunk: [String],
        targetLanguage: String,
        glossaryHint: String,
        provider: AIProviderConfig,
        apiKey: String,
        translationOptions: [String: String]?,
        workingChunkSize: Int
    ) async throws -> [String] {
        var candidates: [(AIProviderConfig, String)] = [(provider, apiKey)]
        for fallbackId in providerManager.fallbackChainIds(for: provider.id) {
            guard let fallbackProvider = providerRegistry.get(fallbackId) else { continue }
            let fallbackKey = providerManager.getApiKey(for: fallbackId)
            guard !fallbackKey.isEmpty else { continue }
            candidates.append((fallbackProvider, fallbackKey))
        }

        var lastError: Error = AIError.invalidResponse
        for (index, candidate) in candidates.enumerated() {
            do {
                return try await translateChunkOnSingleProvider(
                    chunk: chunk,
                    targetLanguage: targetLanguage,
                    glossaryHint: glossaryHint,
                    provider: candidate.0,
                    apiKey: candidate.1,
                    translationOptions: translationOptions,
                    workingChunkSize: workingChunkSize
                )
            } catch {
                lastError = (error is BatchTranslationParseError) ? AIError.invalidResponse : error
                let kind = failureKind(from: lastError)
                let canFallback = AIErrorClassifier.isTransient(kind)
                    || AIErrorClassifier.shouldFallbackAfterParseRetries(kind)
                if canFallback && index + 1 < candidates.count {
                    let next = candidates[index + 1].0
                    activeTaskMetrics.recordFallback(from: candidate.0.id, to: next.id)
                    print("Chunk translation failed on \(candidate.0.displayName) (\(kind)), trying next provider")
                    continue
                }
                throw lastError
            }
        }
        throw lastError
    }

    private func translateChunkOnSingleProvider(
        chunk: [String],
        targetLanguage: String,
        glossaryHint: String,
        provider: AIProviderConfig,
        apiKey: String,
        translationOptions: [String: String]?,
        workingChunkSize: Int
    ) async throws -> [String] {
        if chunk.count > workingChunkSize {
            var results: [String] = []
            for sub in BatchTranslationParser.chunk(chunk, size: workingChunkSize) {
                let part = try await translateChunkOnSingleProvider(
                    chunk: sub,
                    targetLanguage: targetLanguage,
                    glossaryHint: glossaryHint,
                    provider: provider,
                    apiKey: apiKey,
                    translationOptions: translationOptions,
                    workingChunkSize: workingChunkSize
                )
                results.append(contentsOf: part)
            }
            return results
        }

        let optionsForProvider: [String: String]? = {
            if provider.id == "aliyun" {
                return translationOptions ?? ["source_lang": "auto", "target_lang": targetLanguage]
            }
            return translationOptions
        }()

        let prompt = BatchTranslationParser.buildPrompt(
            texts: chunk,
            targetLanguage: targetLanguage,
            glossaryHint: glossaryHint
        )
        let messages = [Message(role: "user", content: prompt)]

        do {
            let response = try await executeRequest(
                provider: provider,
                apiKey: apiKey,
                messages: messages,
                translationOptions: optionsForProvider
            )
            return try BatchTranslationParser.parse(response: response, expectedCount: chunk.count)
        } catch {
            let kind = failureKind(from: error)
            if AIErrorClassifier.isParseFailure(kind), chunk.count > 1 {
                let nextSize = AIErrorClassifier.nextChunkSize(afterFailureWith: max(workingChunkSize, chunk.count))
                if nextSize < chunk.count {
                    print("Parse failed for chunk size \(chunk.count), retrying with size \(nextSize)")
                    return try await translateChunkOnSingleProvider(
                        chunk: chunk,
                        targetLanguage: targetLanguage,
                        glossaryHint: glossaryHint,
                        provider: provider,
                        apiKey: apiKey,
                        translationOptions: translationOptions,
                        workingChunkSize: nextSize
                    )
                }
            }
            throw error
        }
    }

    private func executeRequestWithFallback(provider: AIProviderConfig,
                                          apiKey: String,
                                          messages: [Message],
                                          translationOptions: [String: String]? = nil,
                                          allowParseFallback: Bool = false) async throws -> String {
        var providersToTry: [(AIProviderConfig, String)] = [(provider, apiKey)]
        for fallbackId in providerManager.fallbackChainIds(for: provider.id) {
            guard let fallbackProvider = providerRegistry.get(fallbackId) else { continue }
            let fallbackKey = providerManager.getApiKey(for: fallbackId)
            guard !fallbackKey.isEmpty else { continue }
            providersToTry.append((fallbackProvider, fallbackKey))
        }

        var lastError: Error = AIError.invalidConfiguration("No provider available")
        for (index, candidate) in providersToTry.enumerated() {
            do {
                let optionsForCandidate: [String: String]? = {
                    if candidate.0.id == "aliyun" {
                        return translationOptions ?? ["source_lang": "auto", "target_lang": "English"]
                    }
                    return translationOptions
                }()
                return try await executeRequest(
                    provider: candidate.0,
                    apiKey: candidate.1,
                    messages: messages,
                    translationOptions: optionsForCandidate
                )
            } catch {
                lastError = error
                let kind = failureKind(from: error)
                let canFallback = AIErrorClassifier.isTransient(kind)
                    || (allowParseFallback && AIErrorClassifier.shouldFallbackAfterParseRetries(kind))
                let hasNext = index + 1 < providersToTry.count
                if canFallback && hasNext {
                    let next = providersToTry[index + 1].0
                    activeTaskMetrics.recordFallback(from: candidate.0.id, to: next.id)
                    print("Provider \(candidate.0.displayName) failed (\(kind)), trying next fallback")
                    continue
                }
                throw error
            }
        }
        throw lastError
    }

    private func failureKind(from error: Error) -> AIFailureKind {
        if let aiError = error as? AIError {
            switch aiError {
            case .rateLimitExceeded:
                return .rateLimited
            case .unauthorized:
                return .unauthorized
            case .invalidConfiguration:
                return .invalidConfiguration
            case .invalidURL:
                return .badRequest
            case .invalidResponse, .jsonError:
                return .invalidStructuredResponse
            case .networkError:
                return .networkFailure
            case .apiError(let message):
                return AIErrorClassifier.kind(fromLocalizedDescription: message)
            }
        }
        if error is BatchTranslationParseError {
            return .invalidStructuredResponse
        }
        return AIErrorClassifier.kind(fromLocalizedDescription: error.localizedDescription)
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

}
