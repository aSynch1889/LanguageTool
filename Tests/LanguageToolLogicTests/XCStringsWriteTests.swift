import XCTest
@testable import LanguageToolLogic

/// Round-trip coverage lives mainly in app target; here we keep parser invariants used by Master save.
final class XCStringsWriteSupportTests: XCTestCase {
    func testParserProvidesStableKeyOrderForMaster() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "version": "1.0",
          "strings": {
            "b": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "B" } } } },
            "a": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "A" } } } }
          }
        }
        """.data(using: .utf8)!

        let parsed = try XCStringsParser.parse(data: json)
        XCTAssertEqual(parsed.entries.map(\.key), ["a", "b"])
    }
}
