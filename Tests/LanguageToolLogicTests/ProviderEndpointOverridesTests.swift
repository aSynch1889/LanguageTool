import XCTest
@testable import LanguageToolLogic

final class ProviderEndpointOverridesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProviderEndpointOverridesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEffectiveModelFallsBackToDefault() {
        let store = ProviderEndpointOverrides(userDefaults: defaults)
        XCTAssertEqual(store.effectiveModel(for: "kimi", defaultModel: "moonshot-v1-8k"), "moonshot-v1-8k")
    }

    func testModelOverrideWinsOverDefault() {
        let store = ProviderEndpointOverrides(userDefaults: defaults)
        store.setModel("moonshot-v1-32k", for: "kimi")
        XCTAssertEqual(store.effectiveModel(for: "kimi", defaultModel: "moonshot-v1-8k"), "moonshot-v1-32k")
    }

    func testEmptyModelOverrideClearsToDefault() {
        let store = ProviderEndpointOverrides(userDefaults: defaults)
        store.setModel("moonshot-v1-32k", for: "kimi")
        store.setModel("", for: "kimi")
        XCTAssertEqual(store.effectiveModel(for: "kimi", defaultModel: "moonshot-v1-8k"), "moonshot-v1-8k")
    }

    func testBaseURLOverrideAndClear() {
        let store = ProviderEndpointOverrides(userDefaults: defaults)
        let defaultURL = "https://api.moonshot.cn/v1/chat/completions"
        XCTAssertEqual(store.effectiveBaseURL(for: "kimi", defaultURL: defaultURL), defaultURL)

        store.setBaseURL("https://proxy.example.com/v1/chat/completions", for: "kimi")
        XCTAssertEqual(
            store.effectiveBaseURL(for: "kimi", defaultURL: defaultURL),
            "https://proxy.example.com/v1/chat/completions"
        )

        store.setBaseURL("   ", for: "kimi")
        XCTAssertEqual(store.effectiveBaseURL(for: "kimi", defaultURL: defaultURL), defaultURL)
    }
}
