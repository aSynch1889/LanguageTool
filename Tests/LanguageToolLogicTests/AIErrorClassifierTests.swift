import XCTest
@testable import LanguageToolLogic

final class AIErrorClassifierTests: XCTestCase {
    func testTransientErrorsAllowFallback() {
        XCTAssertTrue(AIErrorClassifier.isTransient(.rateLimited))
        XCTAssertTrue(AIErrorClassifier.isTransient(.networkFailure))
        XCTAssertTrue(AIErrorClassifier.isTransient(.serverFailure))
        XCTAssertTrue(AIErrorClassifier.isTransient(.timeout))
    }

    func testConfigurationErrorsDoNotFallback() {
        XCTAssertFalse(AIErrorClassifier.isTransient(.unauthorized))
        XCTAssertFalse(AIErrorClassifier.isTransient(.invalidConfiguration))
        XCTAssertFalse(AIErrorClassifier.isTransient(.badRequest))
    }

    func testParseFailureIsRetryableThenFallbackable() {
        XCTAssertTrue(AIErrorClassifier.isParseFailure(.invalidStructuredResponse))
        XCTAssertTrue(AIErrorClassifier.shouldFallbackAfterParseRetries(.invalidStructuredResponse))
    }

    func testNextChunkSizeHalvesButNotBelowOne() {
        XCTAssertEqual(AIErrorClassifier.nextChunkSize(afterFailureWith: 40), 20)
        XCTAssertEqual(AIErrorClassifier.nextChunkSize(afterFailureWith: 3), 1)
        XCTAssertEqual(AIErrorClassifier.nextChunkSize(afterFailureWith: 1), 1)
    }

    func testFallbackChainSkipsPrimaryAndDuplicates() {
        let chain = AIErrorClassifier.orderedFallbackChain(
            primaryId: "kimi",
            candidates: ["kimi", "deepseek", "", "deepseek", "glm"]
        )
        XCTAssertEqual(chain, ["deepseek", "glm"])
    }
}
