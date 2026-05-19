import Foundation
import AppKit

class LocalizationJSONGenerator {
    static func generateJSON(for entries: [JsonUtils.XCStringsTranslationEntry],
                           languages: [String],
                           sourceLanguage: String,
                           skipExistingTranslations: Bool = true) async -> Data? {
        var localizationData: [String: Any] = [
            "version": "1.0",
            "sourceLanguage": sourceLanguage,
            "strings": [:]
        ]
        
        var stringsDict: [String: Any] = [:]
        
        // 语言名称映射
        let languageNames = [
            "en": "English",
            "zh-Hans": "Simplified Chinese",
            "zh-Hant": "Traditional Chinese",
            "ja": "Japanese",
            "ko": "Korean",
            "es": "Spanish",
            "fr": "French",
            "de": "German"
        ]
        
        // 先按 key 初始化，保留 source 与已有翻译
        for entry in entries {
            var localizations: [String: Any] = [
                sourceLanguage: [
                    "stringUnit": [
                        "state": "translated",
                        "value": entry.sourceValue
                    ]
                ]
            ]

            for (langCode, value) in entry.existingTranslations where !value.isEmpty {
                localizations[langCode] = [
                    "stringUnit": [
                        "state": "translated",
                        "value": value
                    ]
                ]
            }

            stringsDict[entry.key] = ["localizations": localizations]
        }

        // 为每种语言批量翻译所有条目
        for language in languages {
            if language == sourceLanguage {
                continue
            }

            do {
                // 使用优化后的批量翻译方法，支持跳过已有翻译
                print("Starting batch translation [\(language)]...")

                // 准备现有翻译数组
                let existingTranslationsForLanguage = entries.map { entry -> String? in
                    entry.existingTranslations[language]
                }

                let result = try await AIServiceV2.shared.batchTranslateWithExisting(
                    texts: entries.map { $0.sourceValue },
                    to: languageNames[language] ?? language,
                    existingTranslations: existingTranslationsForLanguage,
                    skipExisting: skipExistingTranslations
                )
                let translations = result.translations
                
                // 将翻译结果添加到字典中
                for (index, entry) in entries.enumerated() {
                    if var localizations = stringsDict[entry.key] as? [String: Any],
                       var localizationsDict = localizations["localizations"] as? [String: Any],
                       index < translations.count {
                        let translationValue = translations[index]
                        localizationsDict[language] = [
                            "stringUnit": [
                                "state": translationValue.isEmpty ? "needs_review" : "translated",
                                "value": translationValue
                            ]
                        ]
                        localizations["localizations"] = localizationsDict
                        stringsDict[entry.key] = localizations
                    }
                }
                
                print("✅ Batch translation successful [\(language)]: \(result.statistics.summary)")
            } catch {
                print("❌ Batch translation failed [\(language)]: \(error.localizedDescription)")
                // 翻译失败时为所有键设置空值
                for entry in entries {
                    if var localizations = stringsDict[entry.key] as? [String: Any],
                       var localizationsDict = localizations["localizations"] as? [String: Any] {
                        localizationsDict[language] = [
                            "stringUnit": [
                                "state": "needs_review",
                                "value": ""
                            ]
                        ]
                        localizations["localizations"] = localizationsDict
                        stringsDict[entry.key] = localizations
                    }
                }
            }
        }
        
        localizationData["strings"] = stringsDict
        
        do {
            return try JSONSerialization.data(withJSONObject: localizationData, options: [.prettyPrinted, .sortedKeys])
        } catch {
            print("❌ 生成 JSON 失败: \(error)")
            return nil
        }
    }

    static func saveJSONToFile(data: Data?, fileName: String) { // 修改参数为文件名
        guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
            print("Invalid JSON data")
            return
        }

        // 获取 Documents 目录的路径
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access Documents directory")
            return
        }

        // 创建文件路径
        let filePath = documentsDirectory.appendingPathComponent(fileName).path

        do {
            try jsonString.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("JSON file saved to \(filePath)")
        } catch {
            print("Error writing JSON to file: \(error)")
        }
    }
    
    /// 选择保存路径保存 json 文件
    /// - Parameter data: 待保存的数据
    static func saveJSONToFile(data: Data?) {
        guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
            print("Invalid JSON data")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true // 允许用户创建文件夹
        savePanel.title = "Save JSON File" // 设置窗口标题
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "\(dateFormatter.string(from: Date())).json"
        
        savePanel.nameFieldStringValue = fileName // 设置默认文件名

        // 显示保存面板
        savePanel.begin { (result) in
            if result == .OK {
                guard let url = savePanel.url else {
                    print("No URL selected")
                    return
                }

                do {
                    try jsonString.write(to: url, atomically: true, encoding: .utf8)
                    print("JSON file saved to \(url)")
                } catch {
                    print("Error writing JSON to file: \(error)")
                }
            }
        }
    }
}
