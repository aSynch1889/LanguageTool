import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let providerManager = AIProviderManager.shared
    
    @Published var apiKey: String {
        didSet {
            providerManager.setApiKey(apiKey, for: "deepseek")
        }
    }
    
    private init() {
        self.apiKey = providerManager.getApiKey(for: "deepseek")
    }
}
