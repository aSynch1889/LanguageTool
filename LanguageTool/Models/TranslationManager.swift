import Foundation

class TranslationManager {
    static let shared = TranslationManager()
    
    private init() {}
    
    func parseInputFile(at path: String, platform: PlatformType) async -> [TranslationItem] {
        do {
            print("Attempting to parse file at path:", path)
            print("Selected platform:", platform)
            
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)
            print("Successfully read file data, size:", data.count)
            
            let items: [TranslationItem]
            switch platform {
            case .iOS:
                if path.hasSuffix(".xcstrings") {
                    print("Parsing as xcstrings file")
                    items = try await parseXCStrings(data: data)
                } else {
                    print("Parsing as strings file")
                    items = try await parseStringsFile(data: data)
                }
            case .electron:
                print("Parsing as JSON file")
                items = try await parseJsonFile(data: data)
            case .flutter:
                print("Parsing as ARB file")
                items = try await parseArbFile(data: data)
            }
            
            print("Successfully parsed items count:", items.count)
            if items.isEmpty {
                print("Warning: No items were parsed from the file")
            } else {
                print("Sample item - Key:", items[0].key)
                print("Sample item - Translations:", items[0].translations)
            }
            
            return items
        } catch {
            print("Error parsing file:", error)
            print("Error details:", String(describing: error))
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key:", key)
                    print("Context:", context)
                case .typeMismatch(let type, let context):
                    print("Type mismatch:", type)
                    print("Context:", context)
                default:
                    print("Other decoding error:", decodingError)
                }
            }
            return []
        }
    }
    
    private func parseXCStrings(data: Data) async throws -> [TranslationItem] {
        print("Starting parseXCStrings")
        let decoder = JSONDecoder()
        
        // 更新数据结构以匹配实际的 JSON 格式
        struct XCStringsContainer: Codable {
            struct StringEntry: Codable {
                // 源语言的值
                let source: Source?
                // 注释
                let comment: String?
                // 翻译
                let localizations: [String: Localization]?
                
                struct Source: Codable {
                    let stringUnit: StringUnit
                }
                
                struct Localization: Codable {
                    let stringUnit: StringUnit
                }
                
                struct StringUnit: Codable {
                    let state: String?
                    let value: String
                }
            }
            
            let sourceLanguage: String
            let strings: [String: StringEntry]
            let version: String
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw JSON data:", jsonString)
        }
        
        let xcstrings = try decoder.decode(XCStringsContainer.self, from: data)
        
        print("Parsed sourceLanguage:", xcstrings.sourceLanguage)
        print("Number of strings:", xcstrings.strings.count)
        print("Available keys:", xcstrings.strings.keys)
        
        let items = xcstrings.strings.map { key, entry in
            var translations: [String: String] = [:]
            
            // 添加源语言的值
            if let sourceValue = entry.source?.stringUnit.value {
                translations[xcstrings.sourceLanguage] = sourceValue
            }
            
            // 添加其他语言的翻译
            if let localizations = entry.localizations {
                for (languageCode, localization) in localizations {
                    translations[languageCode] = localization.stringUnit.value
                }
            }
            
            let item = TranslationItem(
                key: key,
                translations: translations,
                comment: entry.comment ?? ""
            )
            print("Created item - Key:", key)
            print("Created item - Translations:", translations)
            return item
        }
        
        print("Finished parsing, returning \(items.count) items")
        return items
    }
    
    private func parseStringsFile(data: Data) async throws -> [TranslationItem] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TranslationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid strings file encoding"])
        }
        
        var translations: [TranslationItem] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("//") else { continue }
            
            if let match = try? NSRegularExpression(pattern: "\"(.*)\"\\s*=\\s*\"(.*)\";")
                .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                
                let key = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
                let value = String(trimmed[Range(match.range(at: 2), in: trimmed)!])
                
                // 对于 .strings 文件，我们假设它是基础语言（通常是英语）
                translations.append(TranslationItem(
                    key: key,
                    translations: ["en": value]
                ))
            }
        }
        
        return translations
    }
    
    private func parseJsonFile(data: Data) async throws -> [TranslationItem] {
        let decoder = JSONDecoder()
        let json = try decoder.decode([String: String].self, from: data)
        
        return json.map { key, value in
            // 对于 JSON 文件，我们假设它是基础语言
            TranslationItem(
                key: key,
                translations: ["en": value]
            )
        }
    }
    
    private func parseArbFile(data: Data) async throws -> [TranslationItem] {
        let decoder = JSONDecoder()
        let json = try decoder.decode([String: String].self, from: data)
        
        return json.compactMap { key, value in
            guard !key.hasPrefix("@") else { return nil }
            // 对于 ARB 文件，我们假设它是基础语言
            return TranslationItem(
                key: key,
                translations: ["en": value]
            )
        }
    }
}