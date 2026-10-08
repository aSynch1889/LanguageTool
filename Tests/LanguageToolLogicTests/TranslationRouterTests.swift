import XCTest
@testable import LanguageToolLogic

final class TranslationRouterTests: XCTestCase {
    func testLargeBatchPrefersMT() {
        let decision = TranslationRouter.decide(
            batchCount: 80,
            primaryProviderId: "kimi",
            mtProviderId: "aliyun",
            mtAvailable: true
        )
        XCTAssertEqual(decision.preferredProviderId, "aliyun")
        XCTAssertEqual(decision.reason, .largeBatchUsesMT)
    }

    func testSmallBatchKeepsPrimaryLLM() {
        let decision = TranslationRouter.decide(
            batchCount: 5,
            primaryProviderId: "kimi",
            mtProviderId: "aliyun",
            mtAvailable: true
        )
        XCTAssertEqual(decision.preferredProviderId, "kimi")
        XCTAssertEqual(decision.reason, .keepPrimary)
    }

    func testMTUnavailableKeepsPrimary() {
        let decision = TranslationRouter.decide(
            batchCount: 100,
            primaryProviderId: "deepseek",
            mtProviderId: "aliyun",
            mtAvailable: false
        )
        XCTAssertEqual(decision.preferredProviderId, "deepseek")
    }
}
