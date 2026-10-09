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

    func testSuggestedModelsForDeepSeekIncludesChatAndReasoner() {
        let models = OpenAICompatibleEndpointNormalizer.suggestedModels(
            forBaseURL: "https://api.deepseek.com/chat/completions"
        )
        XCTAssertEqual(models.first, "deepseek-flash")
        XCTAssertTrue(models.contains("deepseek-chat"))
        XCTAssertTrue(models.contains("deepseek-reasoner"))
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
        XCTAssertTrue(
            OpenAICompatibleEndpointNormalizer.suggestedModels(
                forBaseURL: "https://proxy.example.com/v1"
            ).isEmpty
        )
    }

    func testProviderCatalogPrefersBaseURLModels() {
        let models = ProviderCatalog.suggestedModels(
            forProviderId: "openai_compatible",
            baseURL: "https://api.deepseek.com"
        )
        XCTAssertEqual(models.first, "deepseek-flash")
    }
}
