import Foundation

class JsonUtils {
    /// 从 JSON 文件中提取所有需要翻译的 key/value 和源语言
    static func extractValuesFromXCStrings(from inputFilePath: String) -> (entries: [XCStringsTranslationEntry], sourceLanguage: String)? {
        do {
            let parsed = try XCStringsParser.parseFile(at: inputFilePath)
            print("✅ 成功提取 \(parsed.entries.count) 个待翻译条目")
            return parsed
        } catch {
            print("❌ JSON 文件读取或解析失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从JSON文件中提取值并生成本地化文件
    static func convertToLocalizationFile(
        from inputPath: String,
        to outputPath: String,
        languages: [String],
        skipExistingTranslations: Bool = true
    ) async -> (success: Bool, message: String) {
        guard let extractedData = extractValuesFromXCStrings(from: inputPath) else {
            return (false, "Failed to extract values for translation")
        }

        let generation = await LocalizationJSONGenerator.generateJSON(
            for: extractedData.entries,
            languages: languages,
            sourceLanguage: extractedData.sourceLanguage,
            skipExistingTranslations: skipExistingTranslations
        )

        guard let jsonData = generation.data else {
            return (false, "Failed to generate localization JSON")
        }

        do {
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            var message = "Successfully generated localized JSON file containing \(extractedData.entries.count) translation items".localized
            if !generation.report.isEmpty {
                message += "\n\(generation.report)"
            }
            let hasTargets = languages.contains { $0 != extractedData.sourceLanguage }
            // Success if file written and (no targets, or at least one language OK). Partial failures stay in report.
            let success = !hasTargets || generation.succeededLanguages > 0
            return (success, message)
        } catch {
            return (false, "Failed to write file: \(error.localizedDescription)")
        }
    }
}
