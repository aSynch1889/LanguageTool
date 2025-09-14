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

    private let userDefaults = UserDefaults.standard
    private let apiKeyPrefix = "apiKey_"

    private init() {
        loadApiKeys()
        loadSelectedProvider()
    }

    func setApiKey(_ key: String, for providerId: String) {
        apiKeys[providerId] = key
        userDefaults.set(key, forKey: apiKeyPrefix + providerId)
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

    func getSelectedProvider() -> AIProviderConfig? {
        return AIProviderRegistry.shared.get(selectedProviderId)
    }

    private func loadApiKeys() {
        // 迁移旧的API密钥格式到新格式
        migrateOldApiKeys()

        // 加载新格式的API密钥
        let knownProviders = ["deepseek", "gemini", "aliyun", "kimi", "glm"]
        for providerId in knownProviders {
            let key = userDefaults.string(forKey: apiKeyPrefix + providerId) ?? ""
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
    }

    private func migrateOldApiKeys() {
        // 迁移旧的API密钥
        if let oldDeepSeekKey = userDefaults.string(forKey: "apiKey"), !oldDeepSeekKey.isEmpty {
            apiKeys["deepseek"] = oldDeepSeekKey
            userDefaults.set(oldDeepSeekKey, forKey: apiKeyPrefix + "deepseek")
        }

        if let oldGeminiKey = userDefaults.string(forKey: "geminiApiKey"), !oldGeminiKey.isEmpty {
            apiKeys["gemini"] = oldGeminiKey
            userDefaults.set(oldGeminiKey, forKey: apiKeyPrefix + "gemini")
        }

        if let oldAliyunKey = userDefaults.string(forKey: "aliyunApiKey"), !oldAliyunKey.isEmpty {
            apiKeys["aliyun"] = oldAliyunKey
            userDefaults.set(oldAliyunKey, forKey: apiKeyPrefix + "aliyun")
        }
    }
}