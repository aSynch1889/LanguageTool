import XCTest
@testable import LanguageToolLogic

final class OpenAICompatibleEndpointNormalizerTests: XCTestCase {
    func testHostOnlyBecomesChatCompletions() {
        XCTAssertEqual(
            OpenAICompatibleEndpointNormalizer.normalize("https://api.deepseek.com"),
            "https://api.deepseek.com/chat/completions"
        )
    }

    func testHostWithV1BecomesChatCompletions() {
        XCTAssertEqual(
            OpenAICompatibleEndpointNormalizer.normalize("https://api.deepseek.com/v1"),
            "https://api.deepseek.com/v1/chat/completions"
        )
    }

    func testFullPathUnchanged() {
        let full = "https://api.deepseek.com/v1/chat/completions"
        XCTAssertEqual(OpenAICompatibleEndpointNormalizer.normalize(full), full)
    }

    func testTrailingSlashStrippedBeforeNormalize() {
        XCTAssertEqual(
            OpenAICompatibleEndpointNormalizer.normalize("https://api.openai.com/v1/"),
            "https://api.openai.com/v1/chat/completions"
        )
    }

    func testSuggestedModelForDeepSeek() {
        XCTAssertEqual(
            OpenAICompatibleEndpointNormalizer.suggestedModel(
                forBaseURL: "https://api.deepseek.com"
            ),
            "deepseek-flash"
        )
    }

    func testSuggestedModelForMoonshot() {
        XCTAssertEqual(
            OpenAICompatibleEndpointNormalizer.suggestedModel(
                forBaseURL: "https://api.moonshot.cn/v1/chat/completions"
            ),
            "moonshot-v1-8k"
        )
    }

    func testSuggestedModelNilForUnknown() {
        XCTAssertNil(
            OpenAICompatibleEndpointNormalizer.suggestedModel(
                forBaseURL: "https://proxy.example.com/v1"
            )
        )
    }
}
