import Foundation

enum AIServiceError: Error {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case invalidData
    case apiKeyMissing
} 