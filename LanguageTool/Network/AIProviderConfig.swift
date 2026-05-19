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

    // Custom hash and equality to handle the protocol types
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
        // Will register default providers after we create the specific implementations
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
        // 迁移旧的API密钥格式到新格式
        migrateOldApiKeys()

        // 从 Keychain 加载 API 密钥
        let knownProviders = ["deepseek", "gemini", "aliyun", "kimi", "glm"]
        for providerId in knownProviders {
            let key = keychain.get(for: apiKeyPrefix + providerId) ?? ""
            apiKeys[providerId] = key
        }
    }

    private func loadSelectedProvider() {
        // 迁移旧的选择格式到新格式
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
