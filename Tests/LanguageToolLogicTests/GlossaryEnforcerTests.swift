import XCTest
@testable import LanguageToolLogic

final class GlossaryEnforcerTests: XCTestCase {
    func testMissingTermIsReported() {
        let entries = [GlossaryEntry(source: "iPhone", target: "iPhone")]
        let issues = GlossaryEnforcer.validate(
            source: "Buy iPhone today",
            translation: "今天买手机",
            entries: entries
        )
        XCTAssertFalse(issues.isEmpty)
    }

    func testApplyPreferredTermsReplacesLeakedSourceToken() {
        let entries = [GlossaryEntry(source: "Settings", target: "設定")]
        let fixed = GlossaryEnforcer.applyPreferredTerms(
            source: "Open Settings",
            translation: "打开 Settings",
            entries: entries
        )
        XCTAssertEqual(fixed, "打开 設定")
    }
}
