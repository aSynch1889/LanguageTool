import Foundation

class ElectronLocalizationHandler {
    /// 从 Electron 本地化 JSON 文件中提取需要翻译的文本
    static func extractTranslatableContent(from jsonData: [String: Any]) -> [String] {
        var translatableContent: [String] = []
        
        for (_, value) in jsonData {
            if let stringValue = value as? String {
                translatableContent.append(stringValue)
            }
        }
        
        return translatableContent
    }
    
    /// 生成目标语言的 JSON 文件
    static func generateLocalizationFile(originalData: [String: Any], translations: [String]) -> [String: Any] {
        var resultDict: [String: Any] = [:]
        var translationIndex = 0
        
        for (key, _) in originalData {
            if translationIndex < translations.count {
                resultDict[key] = translations[translationIndex]
                translationIndex += 1
            }
        }
        
        return resultDict
    }
    
    /// 处理 Electron 本地化文件转换
    static func processLocalizationFile(
        from inputPath: String,
        to outputPath: String,
        languages: [String],
        skipExistingTranslations: Bool = true
    ) async -> Result<String, Error> {
        do {
            // 读取原始 JSON 文件
            let inputURL = URL(fileURLWithPath: inputPath)
            let jsonData = try Data(contentsOf: inputURL)
            guard let originalDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return .failure(NSError(domain: "", code: -1, 
                    userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]))
            }
            
            // 提取需要翻译的文本
            let translatableContent = extractTranslatableContent(from: originalDict)
            
            // 创建输出目录
            let outputURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: outputURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // 为每种语言生成翻译
            for language in languages {
                print("正在处理语言: \(language)")
                
                // 使用 AIService 进行批量翻译，支持跳过已有翻译
                // 对于Electron JSON文件，由于输入通常只有基础语言，所以existingTranslations都为nil
                let existingTranslations: [String?] = Array(repeating: nil, count: translatableContent.count)

                let result = try await AIServiceV2.shared.batchTranslateWithExisting(
                    texts: translatableContent,
                    to: language,
                    existingTranslations: existingTranslations,
                    skipExisting: skipExistingTranslations
                )
                let translations = result.translations
                
                // 生成目标语言的 JSON 文件
                let translatedJSON = generateLocalizationFile(
                    originalData: originalDict,
                    translations: translations
                )
                
                // 保存翻译后的 JSON 文件
                let languageFileName = "locale-\(language).json"
                let languageFileURL = outputURL.appendingPathComponent(languageFileName)
                
                let jsonData = try JSONSerialization.data(
                    withJSONObject: translatedJSON,
                    options: [.prettyPrinted]
                )
                try jsonData.write(to: languageFileURL)
                
                print("✅ 已生成 \(language) 的本地化文件")
            }
            
            return .success("Successfully generated localized files for all languages".localized)
        } catch {
            return .failure(error)
        }
    }
} 
