import XCTest
@testable import LanguageToolLogic

final class ProviderCatalogTests: XCTestCase {
    func testDefaultProviderIdsAreStreamlined() {
        XCTAssertEqual(
            ProviderCatalog.defaultProviderIds.sorted(),
            ["aliyun", "gemini", "openai_compatible", "openrouter"].sorted()
        )
    }

    func testRemovedProvidersMigrateToOpenAICompatible() {
        XCTAssertEqual(ProviderCatalog.migrateProviderId("deepseek"), "openai_compatible")
        XCTAssertEqual(ProviderCatalog.migrateProviderId("kimi"), "openai_compatible")
        XCTAssertEqual(ProviderCatalog.migrateProviderId("glm"), "openai_compatible")
        XCTAssertEqual(ProviderCatalog.migrateProviderId("aliyun"), "aliyun")
        XCTAssertEqual(ProviderCatalog.migrateProviderId("gemini"), "gemini")
        XCTAssertEqual(ProviderCatalog.migrateProviderId(""), "openai_compatible")
    }

    func testLegacyEndpointHintsForRemovedProviders() {
        let deepseek = ProviderCatalog.legacyEndpointHint(for: "deepseek")
        XCTAssertEqual(deepseek?.baseURL, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(deepseek?.model, "deepseek-flash")
        XCTAssertNil(ProviderCatalog.legacyEndpointHint(for: "aliyun"))
    }
}
