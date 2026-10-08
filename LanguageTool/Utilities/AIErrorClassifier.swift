import Foundation

/// Provider-agnostic failure categories used for retry / fallback decisions.
enum AIFailureKind: Equatable {
    case rateLimited
    case networkFailure
    case serverFailure
    case timeout
    case unauthorized
    case invalidConfiguration
    case badRequest
    case invalidStructuredResponse
    case unknown
}

enum AIErrorClassifier {
    static func isTransient(_ kind: AIFailureKind) -> Bool {
        switch kind {
        case .rateLimited, .networkFailure, .serverFailure, .timeout:
            return true
        case .unauthorized, .invalidConfiguration, .badRequest, .invalidStructuredResponse, .unknown:
            return false
        }
    }

    static func isParseFailure(_ kind: AIFailureKind) -> Bool {
        kind == .invalidStructuredResponse
    }

    /// After local chunk-shrink retries are exhausted, parse failures may move to the next provider.
    static func shouldFallbackAfterParseRetries(_ kind: AIFailureKind) -> Bool {
        kind == .invalidStructuredResponse
    }

    static func nextChunkSize(afterFailureWith size: Int) -> Int {
        max(1, size / 2)
    }

    static func orderedFallbackChain(primaryId: String, candidates: [String]) -> [String] {
        var seen = Set<String>([primaryId])
        var result: [String] = []
        for id in candidates {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }

    static func kind(fromLocalizedDescription description: String) -> AIFailureKind {
        let lower = description.lowercased()
        if lower.contains("rate limit") || lower.contains("429") {
            return .rateLimited
        }
        if lower.contains("unauthorized") || lower.contains("invalid api key") || lower.contains("401") {
            return .unauthorized
        }
        if lower.contains("invalid response") || lower.contains("json") || lower.contains("structured") {
            return .invalidStructuredResponse
        }
        if lower.contains("timeout") || lower.contains("timed out") {
            return .timeout
        }
        if lower.contains("network") {
            return .networkFailure
        }
        if lower.contains("500") || lower.contains("502") || lower.contains("503") || lower.contains("server") {
            return .serverFailure
        }
        if lower.contains("配置") || lower.contains("configuration") {
            return .invalidConfiguration
        }
        if lower.contains("400") || lower.contains("bad request") {
            return .badRequest
        }
        return .unknown
    }
}
