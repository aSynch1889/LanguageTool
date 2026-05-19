import Foundation

class NetworkClient: NetworkClientProtocol {
    static let shared = NetworkClient()

    private let session: URLSession
    private let enableLogging: Bool

    init(session: URLSession = .shared, enableLogging: Bool = false) {
        self.session = session
        self.enableLogging = enableLogging
    }

    func execute(config: HTTPRequestConfig) async throws -> Data {
        var request = URLRequest(url: config.url)
        request.httpMethod = config.method.rawValue
        request.httpBody = config.body

        // Set headers
        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if enableLogging {
            logRequest(config: config, request: request)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            if enableLogging {
                logResponse(httpResponse: httpResponse, data: data)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw AIError.apiError("HTTP Status: \(httpResponse.statusCode)")
            }

            return data
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }

    // MARK: - Private Logging Methods

    private func logRequest(config: HTTPRequestConfig, request: URLRequest) {
        print("🔗 Network Request:")
        print("   URL: \(config.url.absoluteString)")
        print("   Method: \(config.method.rawValue)")
        print("   Headers: \(redactedHeaders(config.headers))")
        if config.body != nil {
            print("   Body: <redacted>")
        }
    }

    private func logResponse(httpResponse: HTTPURLResponse, data: Data) {
        print("📡 Network Response:")
        print("   Status Code: \(httpResponse.statusCode)")
        print("   Data Length: \(data.count) bytes")
    }

    private func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in headers {
            let lowercasedKey = key.lowercased()
            if lowercasedKey.contains("authorization") || lowercasedKey.contains("api-key") || lowercasedKey.contains("key") {
                result[key] = "<redacted>"
            } else {
                result[key] = value
            }
        }
        return result
    }
}
