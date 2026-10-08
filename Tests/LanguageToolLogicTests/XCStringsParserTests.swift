import XCTest
@testable import LanguageToolLogic

final class XCStringsParserTests: XCTestCase {
    func testParsesLocalizationsSourceLanguage() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "version": "1.0",
          "strings": {
            "hello": {
              "comment": "Greeting",
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "Hello" } },
                "ja": { "stringUnit": { "state": "translated", "value": "こんにちは" } }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let parsed = try XCStringsParser.parse(data: json)
        XCTAssertEqual(parsed.sourceLanguage, "en")
        XCTAssertEqual(parsed.entries.count, 1)
        XCTAssertEqual(parsed.entries[0].key, "hello")
        XCTAssertEqual(parsed.entries[0].sourceValue, "Hello")
        XCTAssertEqual(parsed.entries[0].existingTranslations["ja"], "こんにちは")
        XCTAssertEqual(parsed.entries[0].comment, "Greeting")
    }

    func testParsesLegacySourceField() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "version": "1.0",
          "strings": {
            "title": {
              "source": { "stringUnit": { "value": "Title" } },
              "localizations": {
                "zh-Hans": { "stringUnit": { "state": "translated", "value": "标题" } }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let parsed = try XCStringsParser.parse(data: json)
        XCTAssertEqual(parsed.entries.count, 1)
        XCTAssertEqual(parsed.entries[0].sourceValue, "Title")
        XCTAssertEqual(parsed.entries[0].existingTranslations["zh-Hans"], "标题")
    }

    func testSkipsEmptySourceEntries() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "version": "1.0",
          "strings": {
            "empty": { "localizations": {} },
            "ok": {
              "localizations": {
                "en": { "stringUnit": { "state": "translated", "value": "OK" } }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let parsed = try XCStringsParser.parse(data: json)
        XCTAssertEqual(parsed.entries.map(\.key), ["ok"])
    }
}
