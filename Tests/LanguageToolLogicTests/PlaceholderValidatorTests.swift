import XCTest
@testable import LanguageToolLogic

final class PlaceholderValidatorTests: XCTestCase {
    func testPreservesObjCPlaceholders() {
        let issues = PlaceholderValidator.validate(
            source: "Hello %@, you have %d messages",
            translation: "你好 %@，你有 %d 条消息"
        )
        XCTAssertTrue(issues.isEmpty)
    }

    func testDetectsMissingBracePlaceholder() {
        let issues = PlaceholderValidator.validate(
            source: "Welcome {name}!",
            translation: "欢迎！"
        )
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains { $0.contains("{name}") })
    }

    func testNamedBracePlaceholderPreserved() {
        let issues = PlaceholderValidator.validate(
            source: "You have {count} items",
            translation: "你有 {count} 项"
        )
        XCTAssertTrue(issues.isEmpty)
    }
}
