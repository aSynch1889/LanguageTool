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
            id: "deepseek",
            name: "deepseek",
            displayName: "DeepSeek Chat",
            baseURL: "https://api.deepseek.com/v1/chat/completions",
            model: "deepseek-chat",
            authType: .bearer(token: ""),
            requestBuilder: OpenAICompatibleRequestBuilder(options: OpenAICompatiblePresets.deepSeek),
            responseParser: OpenAICompatibleResponseParser()
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
            id: "kimi",
            name: "kimi",
            displayName: "Kimi",
            baseURL: "https://api.moonshot.cn/v1/chat/completions",
            model: "moonshot-v1-8k",
            authType: .bearer(token: ""),
            requestBuilder: OpenAICompatibleRequestBuilder(options: OpenAICompatiblePresets.kimi),
            responseParser: OpenAICompatibleResponseParser()
        ))

        register(AIProviderConfig(
            id: "glm",
            name: "glm",
            displayName: "GLM-4.5",
            baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            model: "glm-4.5",
            authType: .bearer(token: ""),
            requestBuilder: OpenAICompatibleRequestBuilder(options: OpenAICompatiblePresets.glm),
            responseParser: OpenAICompatibleResponseParser()
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
    }
}

// MARK: - AI Provider Manager

class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()

    @Published private var apiKeys: [String: String] = [:]
    @Published var selectedProviderId: String = "deepseek"
    @Published var fallbackProviderId: String = ""
    @Published var secondaryFallbackProviderId: String = ""
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
        selectedProviderId = providerId
        userDefaults.set(providerId, forKey: "selectedAIProvider")
        refreshEndpointDrafts()
    }

    func setFallbackProvider(_ providerId: String) {
        fallbackProviderId = providerId
        userDefaults.set(providerId, forKey: "fallbackAIProvider")
    }

    func setSecondaryFallbackProvider(_ providerId: String) {
        secondaryFallbackProviderId = providerId
        userDefaults.set(providerId, forKey: "secondaryFallbackAIProvider")
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
            candidates: [fallbackProviderId, secondaryFallbackProviderId]
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

    func effectiveModel(for provider: AIProviderConfig) -> String {
        endpointOverrides.effectiveModel(for: provider.id, defaultModel: provider.model)
    }

    func effectiveBaseURL(for provider: AIProviderConfig) -> String {
        endpointOverrides.effectiveBaseURL(for: provider.id, defaultURL: provider.baseURL)
    }

    func commitModelDraft() {
        guard let provider = getSelectedProvider() else { return }
        endpointOverrides.setModel(modelDraft, for: provider.id)
        modelDraft = endpointOverrides.storedModel(for: provider.id)
        if modelDraft.isEmpty {
            modelDraft = provider.model
        }
    }

    func commitBaseURLDraft() {
        guard let provider = getSelectedProvider() else { return }
        endpointOverrides.setBaseURL(baseURLDraft, for: provider.id)
        baseURLDraft = endpointOverrides.effectiveBaseURL(for: provider.id, defaultURL: provider.baseURL)
    }

    func refreshEndpointDrafts() {
        guard let provider = getSelectedProvider() else {
            modelDraft = ""
            baseURLDraft = ""
            return
        }
        let storedModel = endpointOverrides.storedModel(for: provider.id)
        modelDraft = storedModel.isEmpty ? provider.model : storedModel
        baseURLDraft = endpointOverrides.effectiveBaseURL(for: provider.id, defaultURL: provider.baseURL)
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
            let newProviderId: String
            switch oldService {
            case "DeepSeek":
                newProviderId = "deepseek"
            case "Gemini":
                newProviderId = "gemini"
            case "aliyun":
                newProviderId = "aliyun"
            default:
                newProviderId = "deepseek"
            }
            selectedProviderId = newProviderId
            userDefaults.set(newProviderId, forKey: "selectedAIProvider")
            userDefaults.removeObject(forKey: "selectedAIService")
        } else {
            selectedProviderId = userDefaults.string(forKey: "selectedAIProvider") ?? "deepseek"
        }
        fallbackProviderId = userDefaults.string(forKey: "fallbackAIProvider") ?? ""
        secondaryFallbackProviderId = userDefaults.string(forKey: "secondaryFallbackAIProvider") ?? ""
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
            (apiKeyPrefix + "openai_compatible", "openai_compatible")
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
