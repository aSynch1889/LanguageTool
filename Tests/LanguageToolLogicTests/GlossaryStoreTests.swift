import XCTest
@testable import LanguageToolLogic

final class GlossaryStoreTests: XCTestCase {
    func testParseArrowAndEquals() {
        let raw = """
        # comment
        iPhone => iPhone
        Foo=Bar
        bad-line
        """
        let entries = GlossaryStore.parse(raw)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].source, "iPhone")
        XCTAssertEqual(entries[1].target, "Bar")
    }

    func testValidateCountsDroppedLines() {
        let raw = """
        good => ok
        invalid
        too_long_\(String(repeating: "x", count: 250))
        """
        let result = GlossaryStore.validate(raw)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.droppedLines, 2)
    }

    func testPromptHintEmptyWhenNoEntries() {
        XCTAssertEqual(GlossaryStore.promptHint(from: "\n# only comment\n"), "")
    }
}
