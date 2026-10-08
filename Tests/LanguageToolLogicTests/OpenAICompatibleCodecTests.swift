import XCTest
@testable import LanguageToolLogic

final class OpenAICompatibleCodecTests: XCTestCase {
    func testBuildRequestIncludesMessagesAndModel() {
        let body = OpenAICompatibleCodec.buildRequest(
            messages: [
                OpenAICompatibleCodec.Message(role: "user", content: "hello")
            ],
            model: "deepseek-chat",
            options: .standard
        )
        XCTAssertEqual(body["model"] as? String, "deepseek-chat")
        let messages = body["messages"] as? [[String: String]]
        XCTAssertEqual(messages?.first?["content"], "hello")
    }

    func testBuildRequestOptionalTemperatureAndThinking() {
        var options = OpenAICompatibleRequestOptions.standard
        options.temperature = 0.7
        options.maxTokens = 2048
        options.enableThinking = true

        let body = OpenAICompatibleCodec.buildRequest(
            messages: [OpenAICompatibleCodec.Message(role: "user", content: "x")],
            model: "glm-4.5",
            options: options
        )
        XCTAssertEqual(body["temperature"] as? Double, 0.7)
        XCTAssertEqual(body["max_tokens"] as? Int, 2048)
        let thinking = body["thinking"] as? [String: String]
        XCTAssertEqual(thinking?["type"], "enabled")
    }

    func testBuildRequestTranslationOptions() {
        var options = OpenAICompatibleRequestOptions.standard
        options.supportsTranslationOptions = true
        let body = OpenAICompatibleCodec.buildRequest(
            messages: [OpenAICompatibleCodec.Message(role: "user", content: "hi")],
            model: "qwen-mt-turbo",
            options: options,
            translationOptions: ["source_lang": "auto", "target_lang": "English"]
        )
        let translation = body["translation_options"] as? [String: String]
        XCTAssertEqual(translation?["target_lang"], "English")
    }

    func testParseSuccessContent() throws {
        let json = """
        {"choices":[{"message":{"content":"  你好  "}}]}
        """
        let content = try OpenAICompatibleCodec.parseContent(Data(json.utf8), extraction: .trim)
        XCTAssertEqual(content, "你好")
    }

    func testParseAliyunDoubleNewlineExtraction() throws {
        let json = """
        {"choices":[{"message":{"content":"thinking...\\n\\nfinal"}}]}
        """
        let content = try OpenAICompatibleCodec.parseContent(
            Data(json.utf8),
            extraction: .aliyunTrailingSegment
        )
        XCTAssertEqual(content, "final")
    }

    func testParseRateLimitError() {
        let json = #"{"error":{"message":"rate limit exceeded"}}"#
        XCTAssertThrowsError(try OpenAICompatibleCodec.parseContent(Data(json.utf8), extraction: .trim)) { error in
            XCTAssertEqual(error as? OpenAICompatibleParseError, .rateLimitExceeded)
        }
    }

    func testParseUnauthorizedError() {
        let json = #"{"error":{"message":"invalid api key"}}"#
        XCTAssertThrowsError(try OpenAICompatibleCodec.parseContent(Data(json.utf8), extraction: .trim)) { error in
            XCTAssertEqual(error as? OpenAICompatibleParseError, .unauthorized)
        }
    }
}
