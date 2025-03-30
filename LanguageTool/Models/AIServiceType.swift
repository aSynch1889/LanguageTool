import Foundation

enum AIServiceType: String, CaseIterable {
    case deepseek = "DeepSeek"
    case gemini = "Gemini"
    case aliyun
    
    var description: String {
        switch self {
        case .deepseek:
            return "DeepSeek Chat"
        case .gemini:
            return "Google Gemini"
        case .aliyun:
            return "Aliyun"
        }
    }
    
    var modelName: String {
        switch self {
        case .deepseek:
            return "deepseek-chat"
        case .gemini:
            return "gemini-pro"
        case .aliyun:
            return "aliyun-pro"
        }
    }
} 