import Foundation

// MARK: - Core Network Protocols

protocol RequestBuilder {
    func buildRequest(messages: [Message], translationOptions: [String: String]?) -> [String: Any]
}

protocol ResponseParser {
    func parseResponse(data: Data) throws -> String
}

// MARK: - Authentication Types

enum AuthenticationType {
    case bearer(token: String)
    case apiKey(key: String, location: APIKeyLocation)
    case custom(headers: [String: String])
}

enum APIKeyLocation {
    case header(name: String)
    case queryParameter(name: String)
}

// MARK: - HTTP Request Configuration

struct HTTPRequestConfig {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

// MARK: - Network Client Protocol

protocol NetworkClientProtocol {
    func execute(config: HTTPRequestConfig) async throws -> Data
}