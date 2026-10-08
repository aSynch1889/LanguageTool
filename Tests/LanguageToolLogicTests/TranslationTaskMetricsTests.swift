import XCTest
@testable import LanguageToolLogic

final class TranslationTaskMetricsTests: XCTestCase {
    func testSummaryIncludesCounts() {
        var metrics = TranslationTaskMetrics()
        metrics.totalTexts = 10
        metrics.cacheHits = 4
        metrics.networkTranslations = 6
        metrics.fallbackCount = 1
        metrics.durationSeconds = 1.25
        metrics.providerId = "kimi"
        let summary = metrics.summaryLine
        XCTAssertTrue(summary.contains("10"))
        XCTAssertTrue(summary.contains("cache=4"))
        XCTAssertTrue(summary.contains("fallback=1"))
        XCTAssertTrue(summary.contains("kimi"))
    }

    func testRecordFallbackIncrements() {
        var metrics = TranslationTaskMetrics()
        metrics.recordFallback(from: "kimi", to: "deepseek")
        metrics.recordFallback(from: "deepseek", to: "glm")
        XCTAssertEqual(metrics.fallbackCount, 2)
        XCTAssertEqual(metrics.fallbackPath, ["kimi→deepseek", "deepseek→glm"])
    }
}
