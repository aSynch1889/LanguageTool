import Foundation

// MARK: - AI Provider Configuration

struct AIProviderConfig: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let baseURL: String
    let model: String
    let authType: AuthenticationType
    let requestBuilder: any RequestBuilder
    let responseParser: any ResponseParser
    /// When true, Settings always shows editable Base URL (e.g. custom OpenAI-compatible).
    let requiresCustomEndpoint: Bool

    init(
        id: String,
        name: String,
        displayName: String,
        baseURL: String,
        model: String,
        authType: AuthenticationType,
        requestBuilder: any RequestBuilder,
        responseParser: any ResponseParser,
        requiresCustomEndpoint: Bool = false
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.baseURL = baseURL
        self.model = model
        self.authType = authType
        self.requestBuilder = requestBuilder
        self.responseParser = responseParser
        self.requiresCustomEndpoint = requiresCustomEndpoint
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }

    static func == (lhs: AIProviderConfig, rhs: AIProviderConfig) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - AI Provider Registry

class AIProviderRegistry: ObservableObject {
    static let shared = AIProviderRegistry()

    @Published private var providers: [String: AIProviderConfig] = [:]

    private init() {
        setupDefaultProviders()
    }

    func register(_ config: AIProviderConfig) {
        providers[config.id] = config
    }

    func get(_ id: String) -> AIProviderConfig? {
        return providers[id]
    }

    func allProviders() -> [AIProviderConfig] {
        return Array(providers.values).sorted { $0.name < $1.name }
    }

    func providerIds() -> [String] {
        return Array(providers.keys).sorted()
    }

    func remove(_ id: String) {
        providers.removeValue(forKey: id)
    }

    private func setupDefaultProviders() {
        register(AIProviderConfig(
            id: "aliyun",
            name: "aliyun",
            displayName: "Aliyun",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
            model: "qwen-mt-turbo",
            authType: .bearer(token: ""),
            requestBuilder: OpenAICompatibleRequestBuilder(options: OpenAICompatiblePresets.aliyun),
            responseParser: OpenAICompatibleResponseParser(extraction: .aliyunTrailingSegment)
        ))

        register(AIProviderConfig(
            id: "gemini",
            name: "gemini",
            displayName: "Google Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            model: "gemini-1.5-flash",
            authType: .apiKey(key: "", location: .header(name: "x-goog-api-key")),
            requestBuilder: GeminiRequestBuilder(),
            responseParser: GeminiResponseParser()
        ))

        register(AIProviderConfig(
            id: "openai_compatible",
            name: "openai_compatible",
            displayName: "OpenAI Compatible",
            baseURL: "https://api.openai.com/v1/chat/completions",
            model: "gpt-4o-mini",
            authType: .bearer(token: ""),
            requestBuilder: OpenAICompatibleRequestBuilder(options: OpenAICompatiblePresets.custom),
            responseParser: OpenAICompatibleResponseParser(),
            requiresCustomEndpoint: true
        ))

        register(AIProviderConfig(
            id: "openrouter",
            name: "openrouter",
            displayName: "OpenRouter",
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            model: "openai/gpt-4o-mini",
            authType: .bearer(token: ""),
            requestBuilder: OpenAICompatibleRequestBuilder(options: OpenAICompatiblePresets.custom),
            responseParser: OpenAICompatibleResponseParser()
        ))
    }
}

// MARK: - AI Provider Manager

class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()

    @Published private var apiKeys: [String: String] = [:]
    @Published var selectedProviderId: String = ProviderCatalog.fallbackDefaultProviderId
    @Published var fallbackProviderId: String = ""
    @Published var modelDraft: String = ""
    @Published var baseURLDraft: String = ""

    private let userDefaults = UserDefaults.standard
    private let apiKeyPrefix = "apiKey_"
    private let keychain = KeychainService.shared
    private let endpointOverrides = ProviderEndpointOverrides()

    private init() {
        loadApiKeys()
        loadSelectedProvider()
        refreshEndpointDrafts()
    }

    func setApiKey(_ key: String, for providerId: String) {
        apiKeys[providerId] = key
        let account = apiKeyPrefix + providerId
        if key.isEmpty {
            keychain.delete(for: account)
        } else {
            _ = keychain.set(key, for: account)
        }
    }

    func getApiKey(for providerId: String) -> String {
        return apiKeys[providerId] ?? ""
    }

    func hasValidApiKey(for providerId: String) -> Bool {
        let key = getApiKey(for: providerId)
        return !key.isEmpty
    }

    func setSelectedProvider(_ providerId: String) {
        if selectedProviderId != providerId {
            selectedProviderId = providerId
        }
        userDefaults.set(providerId, forKey: "selectedAIProvider")
        refreshEndpointDrafts()
    }

    func setFallbackProvider(_ providerId: String) {
        if fallbackProviderId != providerId {
            fallbackProviderId = providerId
        }
        userDefaults.set(providerId, forKey: "fallbackAIProvider")
    }

    func getSelectedProvider() -> AIProviderConfig? {
        return AIProviderRegistry.shared.get(selectedProviderId)
    }

    func getFallbackProvider() -> AIProviderConfig? {
        guard !fallbackProviderId.isEmpty else { return nil }
        return AIProviderRegistry.shared.get(fallbackProviderId)
    }

    /// Ordered fallback candidates (excludes primary / duplicates / empty).
    func fallbackChainIds(for primaryId: String) -> [String] {
        AIErrorClassifier.orderedFallbackChain(
            primaryId: primaryId,
            candidates: [fallbackProviderId]
        )
    }

    /// Providers whose API keys should be editable on the settings screen together.
    func providersNeedingVisibleKeys() -> [AIProviderConfig] {
        var ids = [selectedProviderId]
        ids.append(contentsOf: fallbackChainIds(for: selectedProviderId))
        var result: [AIProviderConfig] = []
        var seen = Set<String>()
        for id in ids {
            guard !seen.contains(id), let config = AIProviderRegistry.shared.get(id) else { continue }
            seen.insert(id)
            result.append(config)
        }
        return result
    }

    func effectiveBaseURL(for provider: AIProviderConfig) -> String {
        let raw = endpointOverrides.effectiveBaseURL(for: provider.id, defaultURL: provider.baseURL)
        if provider.id == "gemini" || raw.contains("{model}") {
            return raw
        }
        return OpenAICompatibleEndpointNormalizer.normalize(raw)
    }

    func effectiveModel(for provider: AIProviderConfig) -> String {
        let stored = endpointOverrides.effectiveModel(for: provider.id, defaultModel: provider.model)
        let url = effectiveBaseURL(for: provider)
        if let suggested = OpenAICompatibleEndpointNormalizer.suggestedModel(forBaseURL: url),
           stored == provider.model || stored == "gpt-4o-mini" || stored.isEmpty {
            return suggested
        }
        return stored
    }

    func commitModelDraft() {
        guard let provider = getSelectedProvider() else { return }
        endpointOverrides.setModel(modelDraft, for: provider.id)
        modelDraft = endpointOverrides.storedModel(for: provider.id)
        if modelDraft.isEmpty {
            modelDraft = effectiveModel(for: provider)
        }
    }

    func commitBaseURLDraft() {
        guard let provider = getSelectedProvider() else { return }
        let previousURL = effectiveBaseURL(for: provider)
        let trimmed = baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty draft clears the override; show the provider default only after commit.
        guard !trimmed.isEmpty else {
            endpointOverrides.setBaseURL(nil, for: provider.id)
            baseURLDraft = effectiveBaseURL(for: provider)
            return
        }

        let normalized: String
        if provider.id == "gemini" || trimmed.contains("{model}") {
            normalized = trimmed
        } else {
            normalized = OpenAICompatibleEndpointNormalizer.normalize(trimmed)
        }

        endpointOverrides.setBaseURL(normalized, for: provider.id)
        baseURLDraft = normalized

        if let suggested = OpenAICompatibleEndpointNormalizer.suggestedModel(forBaseURL: normalized) {
            let currentModel = endpointOverrides.effectiveModel(for: provider.id, defaultModel: provider.model)
            let shouldReplace =
                currentModel.isEmpty
                || currentModel == provider.model
                || currentModel == "gpt-4o-mini"
                || OpenAICompatibleEndpointNormalizer.suggestedModel(forBaseURL: previousURL) != nil
            if shouldReplace {
                endpointOverrides.setModel(suggested, for: provider.id)
                modelDraft = suggested
            }
        }
    }

    func refreshEndpointDrafts() {
        guard let provider = getSelectedProvider() else {
            if !modelDraft.isEmpty { modelDraft = "" }
            if !baseURLDraft.isEmpty { baseURLDraft = "" }
            return
        }
        let nextBase = effectiveBaseURL(for: provider)
        let nextModel = effectiveModel(for: provider)
        if baseURLDraft != nextBase { baseURLDraft = nextBase }
        if modelDraft != nextModel { modelDraft = nextModel }
    }

    private func loadApiKeys() {
        migrateOldApiKeys()

        let knownProviders = AIProviderRegistry.shared.providerIds()
        for providerId in knownProviders {
            let key = keychain.get(for: apiKeyPrefix + providerId) ?? ""
            apiKeys[providerId] = key
        }
    }

    private func loadSelectedProvider() {
        if let oldService = userDefaults.string(forKey: "selectedAIService") {
            let legacyMapped: String
            switch oldService {
            case "DeepSeek":
                legacyMapped = "deepseek"
            case "Gemini":
                legacyMapped = "gemini"
            case "aliyun":
                legacyMapped = "aliyun"
            default:
                legacyMapped = ProviderCatalog.fallbackDefaultProviderId
            }
            applyMigratedSelection(from: legacyMapped)
            userDefaults.removeObject(forKey: "selectedAIService")
        } else {
            let stored = userDefaults.string(forKey: "selectedAIProvider")
                ?? ProviderCatalog.fallbackDefaultProviderId
            applyMigratedSelection(from: stored)
        }

        let storedFallback = userDefaults.string(forKey: "fallbackAIProvider") ?? ""
        fallbackProviderId = migrateOptionalProviderId(storedFallback)
        userDefaults.set(fallbackProviderId, forKey: "fallbackAIProvider")
        // Drop the unused second-fallback setting from earlier builds.
        userDefaults.removeObject(forKey: "secondaryFallbackAIProvider")
    }

    private func applyMigratedSelection(from rawProviderId: String) {
        let migrated = ProviderCatalog.migrateProviderId(rawProviderId)
        if migrated != rawProviderId {
            seedOpenAICompatibleFromLegacyIfNeeded(legacyProviderId: rawProviderId)
        }
        selectedProviderId = migrated
        userDefaults.set(migrated, forKey: "selectedAIProvider")
    }

    private func migrateOptionalProviderId(_ providerId: String) -> String {
        guard !providerId.isEmpty else { return "" }
        let migrated = ProviderCatalog.migrateProviderId(providerId)
        if migrated != providerId {
            seedOpenAICompatibleFromLegacyIfNeeded(legacyProviderId: providerId)
        }
        // Avoid selecting the same id twice in the chain silently — caller stores value.
        return migrated
    }

    /// When DeepSeek/Kimi/GLM are removed, copy their endpoint + key into OpenAI Compatible once.
    private func seedOpenAICompatibleFromLegacyIfNeeded(legacyProviderId: String) {
        guard let hint = ProviderCatalog.legacyEndpointHint(for: legacyProviderId) else { return }
        let targetId = ProviderCatalog.fallbackDefaultProviderId

        if endpointOverrides.storedModel(for: targetId).isEmpty {
            endpointOverrides.setModel(hint.model, for: targetId)
        }
        if endpointOverrides.storedBaseURL(for: targetId).isEmpty {
            endpointOverrides.setBaseURL(hint.baseURL, for: targetId)
        }

        let legacyKey = keychain.get(for: apiKeyPrefix + legacyProviderId) ?? ""
        let targetKey = keychain.get(for: apiKeyPrefix + targetId) ?? ""
        if !legacyKey.isEmpty && targetKey.isEmpty {
            setApiKey(legacyKey, for: targetId)
        }
    }

    private func migrateOldApiKeys() {
        let legacyKeyMappings: [(legacy: String, provider: String)] = [
            ("apiKey", "deepseek"),
            ("geminiApiKey", "gemini"),
            ("aliyunApiKey", "aliyun"),
            (apiKeyPrefix + "deepseek", "deepseek"),
            (apiKeyPrefix + "gemini", "gemini"),
            (apiKeyPrefix + "aliyun", "aliyun"),
            (apiKeyPrefix + "kimi", "kimi"),
            (apiKeyPrefix + "glm", "glm"),
            (apiKeyPrefix + "openai_compatible", "openai_compatible"),
            (apiKeyPrefix + "openrouter", "openrouter")
        ]

        for mapping in legacyKeyMappings {
            let account = apiKeyPrefix + mapping.provider
            if keychain.get(for: account)?.isEmpty == false {
                userDefaults.removeObject(forKey: mapping.legacy)
                continue
            }

            guard let legacyValue = userDefaults.string(forKey: mapping.legacy), !legacyValue.isEmpty else {
                continue
            }
            _ = keychain.set(legacyValue, for: account)
            userDefaults.removeObject(forKey: mapping.legacy)
        }
    }
}
