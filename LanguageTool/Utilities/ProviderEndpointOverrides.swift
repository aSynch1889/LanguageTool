import Foundation

/// Persists per-provider model / baseURL overrides (UserDefaults).
struct ProviderEndpointOverrides {
    private let userDefaults: UserDefaults
    private let modelPrefix = "aiModelOverride_"
    private let baseURLPrefix = "aiBaseURLOverride_"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func effectiveModel(for providerId: String, defaultModel: String) -> String {
        let value = userDefaults.string(forKey: modelPrefix + providerId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return defaultModel }
        return value
    }

    func setModel(_ model: String?, for providerId: String) {
        let key = modelPrefix + providerId
        let trimmed = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            userDefaults.removeObject(forKey: key)
        } else {
            userDefaults.set(trimmed, forKey: key)
        }
    }

    func storedModel(for providerId: String) -> String {
        userDefaults.string(forKey: modelPrefix + providerId) ?? ""
    }

    func effectiveBaseURL(for providerId: String, defaultURL: String) -> String {
        let value = userDefaults.string(forKey: baseURLPrefix + providerId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return defaultURL }
        return value
    }

    func setBaseURL(_ url: String?, for providerId: String) {
        let key = baseURLPrefix + providerId
        let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            userDefaults.removeObject(forKey: key)
        } else {
            userDefaults.set(trimmed, forKey: key)
        }
    }

    func storedBaseURL(for providerId: String) -> String {
        userDefaults.string(forKey: baseURLPrefix + providerId) ?? ""
    }
}
