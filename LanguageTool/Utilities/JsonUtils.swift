import Foundation

class JsonUtils {
    /// 从 JSON 文件中提取键为中文字符串的键，删除重复项并写入 TXT 文件。
    ///
    /// - Parameters:
    ///   - jsonFilePath: JSON 文件路径。
    ///   - outputFilePath: 输出 TXT 文件路径。
    static func extractChineseKeys(from jsonFilePath: String, to outputFilePath: String) {
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonFilePath)) else {
            print("错误：文件 \(jsonFilePath) 未找到。")
            return
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            print("错误：文件 \(jsonFilePath) 不是有效的 JSON 格式。")
            return
        }

        var chineseKeys = Set<String>()

        func extractKeys(from object: Any) {
            if let dictionary = object as? [String: Any] {
                for (key, value) in dictionary {
                    if key.range(of: "\\p{Han}", options: .regularExpression) != nil {
                        chineseKeys.insert(key)
                    }
                    extractKeys(from: value)
                }
            } else if let array = object as? [Any] {
                for item in array {
                    extractKeys(from: item)
                }
            }
        }

        extractKeys(from: jsonObject)

        let keysArray = Array(chineseKeys)

        do {
            try keysArray.joined(separator: "\n").write(toFile: outputFilePath, atomically: true, encoding: .utf8)
            print("成功提取 \(chineseKeys.count) 个中文键并写入 \(outputFilePath)。")
        } catch {
            print("写入文件 \(outputFilePath) 出错: \(error)")
        }
    }

    /// 新增方法：提取中文并返回字符串数组
    static func extractChineseKeysAsArray(from inputFilePath: String) -> [String]? {
        do {
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: inputFilePath)),
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
                print("❌ JSON 文件读取或解析失败")
                return nil
            }

            var chineseKeys = Set<String>()

            func extractKeys(from object: Any) {
                if let dictionary = object as? [String: Any] {
                    for (key, value) in dictionary {
                        if key.range(of: "\\p{Han}", options: .regularExpression) != nil {
                            chineseKeys.insert(key)
                        }
                        extractKeys(from: value)
                    }
                } else if let array = object as? [Any] {
                    for item in array {
                        extractKeys(from: item)
                    }
                }
            }

            extractKeys(from: jsonObject)
            print("✅ 成功提取 \(chineseKeys.count) 个中文键")
            return Array(chineseKeys)
            
        } catch {
            print("❌ 处理失败: \(error)")
            return nil
        }
    }

    /// 从 JSON 文件中提取所有需要翻译的值和源语言
    static func extractValuesFromXCStrings(from inputFilePath: String) -> (values: [String], sourceLanguage: String, existingTranslations: [String: [String: String]])? {
        do {
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: inputFilePath)),
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                  let strings = jsonObject["strings"] as? [String: Any],
                  let sourceLanguage = jsonObject["sourceLanguage"] as? String else {
                print("❌ JSON 文件读取或解析失败")
                return nil
            }

            var values = Set<String>()
            var existingTranslations: [String: [String: String]] = [:]

            // 遍历 strings 下的所有条目
            for (key, entry) in strings {
                if let entryDict = entry as? [String: Any],
                   let localizations = entryDict["localizations"] as? [String: Any] {

                    // 提取源语言值
                    if let sourceLocalization = localizations[sourceLanguage] as? [String: Any],
                       let stringUnit = sourceLocalization["stringUnit"] as? [String: Any],
                       let value = stringUnit["value"] as? String {
                        values.insert(value)

                        // 收集现有翻译
                        var keyTranslations: [String: String] = [:]
                        for (langCode, localization) in localizations {
                            if let locDict = localization as? [String: Any],
                               let stringUnit = locDict["stringUnit"] as? [String: Any],
                               let translatedValue = stringUnit["value"] as? String,
                               !translatedValue.isEmpty {
                                keyTranslations[langCode] = translatedValue
                            }
                        }
                        existingTranslations[value] = keyTranslations
                    }
                }
            }

            print("✅ 成功提取 \(values.count) 个待翻译值，发现 \(existingTranslations.count) 个已有翻译条目")
            return (Array(values), sourceLanguage, existingTranslations)
        } catch {
            print("❌ 处理失败: \(error)")
            return nil
        }
    }

    /// 从JSON文件中提取值并生成本地化文件
    static func convertToLocalizationFile(from inputPath: String, to outputPath: String, languages: [String], skipExistingTranslations: Bool = true) async -> (success: Bool, message: String) {
        guard let extractedData = extractValuesFromXCStrings(from: inputPath) else {
            return (false, "❌ 提取待翻译值失败")
        }
        
        guard let jsonData = await LocalizationJSONGenerator.generateJSON(
            for: extractedData.values,
            languages: languages,
            sourceLanguage: extractedData.sourceLanguage,
            existingTranslations: extractedData.existingTranslations,
            skipExistingTranslations: skipExistingTranslations
        ) else {
            return (false, "❌ 生成 JSON 失败")
        }
        
        do {
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            return (true, "Successfully generated localized JSON file containing \(extractedData.values.count) translation items".localized)
        } catch {
            return (false, "❌ 写入文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 从JSON文件中提取中文键并生成文本文件
    static func extractChineseKeysToFile(from inputPath: String, to outputPath: String) -> (success: Bool, message: String) {
        do {
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: inputPath)) else {
                return (false, "错误：文件未找到")
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
                return (false, "错误：不是有效的 JSON 格式")
            }

            var chineseKeys = Set<String>()

            func extractKeys(from object: Any) {
                if let dictionary = object as? [String: Any] {
                    for (key, value) in dictionary {
                        if key.range(of: "\\p{Han}", options: .regularExpression) != nil {
                            chineseKeys.insert(key)
                        }
                        extractKeys(from: value)
                    }
                } else if let array = object as? [Any] {
                    for item in array {
                        extractKeys(from: item)
                    }
                }
            }

            extractKeys(from: jsonObject)
            let keysArray = Array(chineseKeys)

            try keysArray.joined(separator: "\n").write(toFile: outputPath, atomically: true, encoding: .utf8)
            return (true, "✅ 成功提取 \(chineseKeys.count) 个中文键并写入文件")
        } catch {
            return (false, "❌ 转换失败：\(error.localizedDescription)")
        }
    }
}
