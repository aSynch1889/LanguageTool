import XCTest
@testable import LanguageToolLogic

final class BatchTranslationParserTests: XCTestCase {
    func testChunkSplitsEvenly() {
        let chunks = BatchTranslationParser.chunk(Array(1...5), size: 2)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[2], [5])
    }

    func testParseJSONArrayExactCount() throws {
        let response = #"["你好", "世界", ""]"#
        let result = try BatchTranslationParser.parse(response: response, expectedCount: 3)
        XCTAssertEqual(result, ["你好", "世界", ""])
    }

    func testParseJSONArrayWithMarkdownFence() throws {
        let response = """
        ```json
        ["A", "B"]
        ```
        """
        let result = try BatchTranslationParser.parse(response: response, expectedCount: 2)
        XCTAssertEqual(result, ["A", "B"])
    }

    func testParseLegacyDelimiterPreservesEmptySegments() throws {
        let response = "one||| |||three"
        let result = try BatchTranslationParser.parse(response: response, expectedCount: 3)
        XCTAssertEqual(result, ["one", "", "three"])
    }

    func testParseCountMismatchThrows() {
        XCTAssertThrowsError(
            try BatchTranslationParser.parse(response: #"["only-one"]"#, expectedCount: 2)
        ) { error in
            guard let parseError = error as? BatchTranslationParseError,
                  case .countMismatch(let expected, let actual) = parseError else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(actual, 1)
        }
    }

    func testBuildPromptContainsCountAndJSON() {
        let prompt = BatchTranslationParser.buildPrompt(
            texts: ["Hello", "World"],
            targetLanguage: "ja (Japanese)",
            glossaryHint: "\nStrict glossary:\niPhone => iPhone\n"
        )
        XCTAssertTrue(prompt.contains("exactly 2 elements"))
        XCTAssertTrue(prompt.contains("Hello"))
        XCTAssertTrue(prompt.contains("iPhone => iPhone"))
    }
}
