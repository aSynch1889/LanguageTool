import Foundation

// MARK: - OpenAI-Compatible Adapter

struct OpenAICompatibleRequestBuilder: RequestBuilder {
    let options: OpenAICompatibleRequestOptions

    func buildRequest(messages: [Message], model: String, translationOptions: [String: String]?) -> [String: Any] {
        OpenAICompatibleCodec.buildRequest(
            messages: messages.map { OpenAICompatibleCodec.Message(role: $0.role, content: $0.content) },
            model: model,
            options: options,
            translationOptions: translationOptions
        )
    }
}

struct OpenAICompatibleResponseParser: ResponseParser {
    let extraction: OpenAICompatibleContentExtraction

    init(extraction: OpenAICompatibleContentExtraction = .trim) {
        self.extraction = extraction
    }

    func parseResponse(data: Data) throws -> String {
        do {
            return try OpenAICompatibleCodec.parseContent(data, extraction: extraction)
        } catch let error as OpenAICompatibleParseError {
            switch error {
            case .rateLimitExceeded:
                throw AIError.rateLimitExceeded
            case .unauthorized:
                throw AIError.unauthorized
            case .apiError(let message):
                throw AIError.apiError(message)
            case .invalidResponse:
                throw AIError.invalidResponse
            }
        } catch {
            throw AIError.jsonError(error)
        }
    }
}

enum OpenAICompatiblePresets {
    static let deepSeek = OpenAICompatibleRequestOptions.standard

    static let kimi = OpenAICompatibleRequestOptions(
        temperature: 0.7,
        maxTokens: 2048,
        enableThinking: false,
        supportsTranslationOptions: false
    )

    static let glm = OpenAICompatibleRequestOptions(
        temperature: 0.7,
        maxTokens: 4096,
        enableThinking: true,
        supportsTranslationOptions: false
    )

    static let aliyun = OpenAICompatibleRequestOptions(
        temperature: nil,
        maxTokens: nil,
        enableThinking: false,
        supportsTranslationOptions: true
    )

    static let custom = OpenAICompatibleRequestOptions.standard
}
