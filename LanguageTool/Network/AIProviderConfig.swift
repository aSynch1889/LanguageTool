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
            requestBuilder: DeepSeekRequestBuilder(),
            responseParser: DeepSeekResponseParser()
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
            requestBuilder: AliyunRequestBuilder(),
            responseParser: AliyunResponseParser()
        ))

        register(AIProviderConfig(
            id: "kimi",
            name: "kimi",
            displayName: "Kimi",
            baseURL: "https://api.moonshot.cn/v1/chat/completions",
            model: "moonshot-v1-8k",
            authType: .bearer(token: ""),
            requestBuilder: KimiRequestBuilder(),
            responseParser: KimiResponseParser()
        ))

        register(AIProviderConfig(
            id: "glm",
            name: "glm",
            displayName: "GLM-4.5",
            baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            model: "glm-4.5",
            authType: .bearer(token: ""),
            requestBuilder: GLMRequestBuilder(),
            responseParser: GLMResponseParser()
        ))
    }
}

// MARK: - AI Provider Manager

class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()

    @Published private var apiKeys: [String: String] = [:]
    @Published var selectedProviderId: String = "deepseek"
    @Published var fallbackProviderId: String = ""

    private let userDefaults = UserDefaults.standard
    private let apiKeyPrefix = "apiKey_"
    private let keychain = KeychainService.shared

    private init() {
        loadApiKeys()
        loadSelectedProvider()
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
    }

    func setFallbackProvider(_ providerId: String) {
        fallbackProviderId = providerId
        userDefaults.set(providerId, forKey: "fallbackAIProvider")
    }

    func getSelectedProvider() -> AIProviderConfig? {
        return AIProviderRegistry.shared.get(selectedProviderId)
    }

    func getFallbackProvider() -> AIProviderConfig? {
        guard !fallbackProviderId.isEmpty else { return nil }
        return AIProviderRegistry.shared.get(fallbackProviderId)
    }

    private func loadApiKeys() {
        migrateOldApiKeys()

        let knownProviders = ["deepseek", "gemini", "aliyun", "kimi", "glm"]
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
            (apiKeyPrefix + "glm", "glm")
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
