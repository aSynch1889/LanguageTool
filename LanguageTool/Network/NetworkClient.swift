import Foundation

class NetworkClient: NetworkClientProtocol {
    static let shared = NetworkClient()

    private let session: URLSession
    private let enableLogging: Bool
    private let timeoutInterval: TimeInterval
    private let maxRetries: Int

    init(session: URLSession = .shared, enableLogging: Bool = {
#if DEBUG
        return true
#else
        return false
#endif
    }(), timeoutInterval: TimeInterval = 60, maxRetries: Int = 2) {
        self.session = session
        self.enableLogging = enableLogging
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
    }

    func execute(config: HTTPRequestConfig) async throws -> Data {
        for attempt in 0...maxRetries {
            try Task.checkCancellation()

            var request = URLRequest(url: config.url)
            request.httpMethod = config.method.rawValue
            request.httpBody = config.body
            request.timeoutInterval = timeoutInterval

            for (key, value) in config.headers {
                request.setValue(value, forHTTPHeaderField: key)
            }

            if enableLogging && attempt == 0 {
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
                    if shouldRetry(httpStatus: httpResponse.statusCode, attempt: attempt) {
                        try await backoffSleep(attempt: attempt, httpResponse: httpResponse)
                        continue
                    }
                    if httpResponse.statusCode == 429 {
                        throw AIError.rateLimitExceeded
                    }
                    throw AIError.apiError("HTTP Status: \(httpResponse.statusCode)")
                }

                return data
            } catch let error as AIError {
                if shouldRetry(error: error, attempt: attempt) {
                    try await backoffSleep(attempt: attempt, httpResponse: nil)
                    continue
                }
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let wrapped = AIError.networkError(error)
                if shouldRetry(error: wrapped, attempt: attempt) {
                    try await backoffSleep(attempt: attempt, httpResponse: nil)
                    continue
                }
                throw wrapped
            }
        }

        throw AIError.invalidResponse
    }

    // MARK: - Private

    private func backoffSleep(attempt: Int, httpResponse: HTTPURLResponse?) async throws {
        if let retryAfter = httpResponse?.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter) {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return
        }

        let base = pow(2.0, Double(attempt)) * 0.4
        let jitter = Double.random(in: 0...0.3)
        let delay = min(base + jitter, 8.0)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func logRequest(config: HTTPRequestConfig, request: URLRequest) {
        print("🔗 Network Request:")
        print("   URL: \(sanitizeURL(config.url))")
        print("   Method: \(config.method.rawValue)")
        print("   Headers: \(sanitizeHeaders(config.headers))")
        if let body = config.body {
            print("   Body: <redacted: \(body.count) bytes>")
        }
    }

    private func logResponse(httpResponse: HTTPURLResponse, data: Data) {
        print("📡 Network Response:")
        print("   Status Code: \(httpResponse.statusCode)")
        print("   Data: <redacted: \(data.count) bytes>")
    }

    private func sanitizeURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return url.absoluteString
        }

        components.queryItems = items.map { item in
            let lower = item.name.lowercased()
            if lower.contains("key") || lower.contains("token") {
                return URLQueryItem(name: item.name, value: "REDACTED")
            }
            return item
        }
        return components.string ?? url.absoluteString
    }

    private func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        var sanitized = headers
        for key in headers.keys {
            let lower = key.lowercased()
            if lower.contains("authorization")
                || lower.contains("api-key")
                || lower == "x-api-key"
                || lower == "x-goog-api-key" {
                sanitized[key] = "REDACTED"
            }
        }
        return sanitized
    }

    private func shouldRetry(httpStatus: Int, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        return httpStatus == 429 || (500...599).contains(httpStatus)
    }

    private func shouldRetry(error: AIError, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        switch error {
        case .networkError, .rateLimitExceeded:
            return true
        default:
            return false
        }
    }
}
