import XCTest
@testable import LanguageToolLogic

final class TranslationMemoryCacheTests: XCTestCase {
    func testHitReturnsCachedTranslation() {
        var cache = TranslationMemoryCache()
        let key = TranslationMemoryCache.makeKey(
            source: "Hello",
            targetLanguage: "zh-Hans",
            glossaryFingerprint: "iphone=iphone"
        )
        cache.set("你好", for: key)
        XCTAssertEqual(cache.get(key), "你好")
    }

    func testDifferentGlossaryMisses() {
        var cache = TranslationMemoryCache()
        let keyA = TranslationMemoryCache.makeKey(
            source: "Hello",
            targetLanguage: "zh-Hans",
            glossaryFingerprint: "a"
        )
        let keyB = TranslationMemoryCache.makeKey(
            source: "Hello",
            targetLanguage: "zh-Hans",
            glossaryFingerprint: "b"
        )
        cache.set("你好", for: keyA)
        XCTAssertNil(cache.get(keyB))
    }

    func testBatchLookupFillsKnownEntries() {
        var cache = TranslationMemoryCache()
        let fp = "g1"
        cache.set("一", for: TranslationMemoryCache.makeKey(source: "one", targetLanguage: "zh", glossaryFingerprint: fp))
        let texts = ["one", "two", "one"]
        let (resolved, missingIndices) = cache.resolveBatch(
            texts: texts,
            targetLanguage: "zh",
            glossaryFingerprint: fp
        )
        XCTAssertEqual(resolved[0], "一")
        XCTAssertNil(resolved[1])
        XCTAssertEqual(resolved[2], "一")
        XCTAssertEqual(missingIndices, [1])
    }
}
