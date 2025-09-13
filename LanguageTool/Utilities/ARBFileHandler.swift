import Foundation

class ARBFileHandler {
    /// ARB 文件中的占位符信息
    struct Placeholder: Codable {
        let type: String
        let example: String?
        let format: String?
    }
    
    /// ARB 文件中的元数据信息
    struct MetadataInfo: Codable {
        let description: String?
        let placeholders: [String: Placeholder]?
    }
    
    /// 从 ARB 文件中提取需要翻译的文本
    static func extractTranslatableContent(from arbData: [String: Any]) -> [String] {
        var translatableContent: [String] = []
        
        func extractFromValue(_ value: Any) {
            if let stringValue = value as? String {
                // 检查是否包含占位符或复数形式
                if !stringValue.isEmpty {
                    translatableContent.append(stringValue)
                }
            } else if let dict = value as? [String: Any] {
                // 处理嵌套字典
                for (key, nestedValue) in dict {
                    if key == "description" {
                        // 提取 description 字段进行翻译
                        if let description = nestedValue as? String {
                            translatableContent.append(description)
                        }
                    } else if !key.hasPrefix("@") {
                        extractFromValue(nestedValue)
                    }
                }
            }
        }
        
        for (key, value) in arbData {
            // 处理元数据中的 description
            if key.hasPrefix("@") && key != "@@locale" {
                if let metaDict = value as? [String: Any] {
                    if let description = metaDict["description"] as? String {
                        translatableContent.append(description)
                    } else if let nestedMeta = metaDict as? [String: [String: Any]] {
                        // 处理嵌套元数据（如 @settings 中的多个 description）
                        for (_, subMeta) in nestedMeta {
                            if let description = subMeta["description"] as? String {
                                translatableContent.append(description)
                            }
                        }
                    }
                }
                continue
            }
            
            // 跳过 @@locale
            if key == "@@locale" {
                continue
            }
            
            extractFromValue(value)
        }
        
        return translatableContent
    }
    
    /// 生成目标语言的 ARB 文件
    static func generateARBFile(originalData: [String: Any], translations: [String], targetLanguage: String) -> [String: Any] {
        var resultARB: [String: Any] = [:]
        resultARB["@@locale"] = targetLanguage
        
        var translationIndex = 0
        
        func translateValue(_ value: Any) -> Any {
            if let stringValue = value as? String {
                if !stringValue.isEmpty && translationIndex < translations.count {
                    let translation = translations[translationIndex]
                    translationIndex += 1
                    return translation
                }
                return stringValue
            } else if let dict = value as? [String: Any] {
                var translatedDict: [String: Any] = [:]
                for (key, nestedValue) in dict {
                    if key == "description" {
                        // 翻译 description 字段
                        if let _ = nestedValue as? String, translationIndex < translations.count {
                            translatedDict[key] = translations[translationIndex]
                            translationIndex += 1
                        } else {
                            translatedDict[key] = nestedValue
                        }
                    } else if key.hasPrefix("@") {
                        // 保持其他元数据不变
                        translatedDict[key] = nestedValue
                    } else {
                        translatedDict[key] = translateValue(nestedValue)
                    }
                }
                return translatedDict
            }
            return value
        }
        
        for (key, value) in originalData {
            if key.hasPrefix("@") && key != "@@locale" {
                // 处理元数据
                if var metaDict = value as? [String: Any] {
                    if let _ = metaDict["description"] as? String, translationIndex < translations.count {
                        metaDict["description"] = translations[translationIndex]
                        translationIndex += 1
                    } else if var nestedMeta = metaDict as? [String: [String: Any]] {
                        // 处理嵌套元数据
                        for (subKey, var subMeta) in nestedMeta {
                            if let _ = subMeta["description"] as? String, translationIndex < translations.count {
                                subMeta["description"] = translations[translationIndex]
                                translationIndex += 1
                            }
                            nestedMeta[subKey] = subMeta
                        }
                        metaDict = nestedMeta
                    }
                    resultARB[key] = metaDict
                }
            } else if key == "@@locale" {
                resultARB[key] = targetLanguage
            } else {
                resultARB[key] = translateValue(value)
            }
        }
        
        return resultARB
    }
    
    /// 处理 ARB 文件转换
    static func processARBFile(from inputPath: String, 
                             to outputPath: String, 
                             languages: [String]) async -> Result<String, Error> {
        do {
            // 读取原始 ARB 文件
            let inputURL = URL(fileURLWithPath: inputPath)
            let arbData = try Data(contentsOf: inputURL)
            guard let originalDict = try JSONSerialization.jsonObject(with: arbData) as? [String: Any] else {
                return .failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid ARB file format"]))
            }
            
            // 提取需要翻译的文本
            let translatableContent = extractTranslatableContent(from: originalDict)
            
            // 创建输出目录
            let outputURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
            
            // 为每种语言生成翻译
            for language in languages {
                print("正在处理语言: \(language)")
                
                // 使用 AIService 进行批量翻译
                let translations = try await AIServiceV2.shared.batchTranslate(
                    texts: translatableContent,
                    to: language
                )
                
                // 生成目标语言的 ARB 文件
                let translatedARB = generateARBFile(
                    originalData: originalDict,
                    translations: translations,
                    targetLanguage: language
                )
                
                // 保存翻译后的 ARB 文件
                let languageFileName = "app_\(language).arb"
                let languageFileURL = outputURL.appendingPathComponent(languageFileName)
                
                let jsonData = try JSONSerialization.data(withJSONObject: translatedARB, options: [.prettyPrinted])
                try jsonData.write(to: languageFileURL)
                
                print("✅ 已生成 \(language) 的 ARB 文件")
            }
            
            return .success("Successfully generated ARB files for all languages".localized)
        } catch {
            return .failure(error)
        }
    }
} 
