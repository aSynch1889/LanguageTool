import Foundation

class TranslationManager {
    static let shared = TranslationManager()
    
    private init() {}
    
    func parseInputFile(at path: String, platform: PlatformType) async -> [TranslationItem] {
        do {
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)
            
            switch platform {
            case .iOS:
                if path.hasSuffix(".xcstrings") {
                    return try await parseXCStrings(data: data)
                } else {
                    return try await parseStringsFile(data: data)
                }
            case .electron:
                return try await parseJsonFile(data: data)
            case .flutter:
                return try await parseArbFile(data: data)
            }
        } catch {
            print("Error parsing file: \(error)")
            return []
        }
    }
    
    private func parseXCStrings(data: Data) async throws -> [TranslationItem] {
        let decoder = JSONDecoder()
        
        struct XCStringsContainer: Codable {
            struct Source: Codable {
                let strings: [String: StringEntry]
            }
            
            struct StringEntry: Codable {
                let extractionState: String?
                let comment: String?
                let localizations: [String: Localization]
            }
            
            struct Localization: Codable {
                let stringUnit: StringUnit
                let state: String?
            }
            
            struct StringUnit: Codable {
                let value: String
                let state: String?
            }
            
            let sourceLanguage: String
            let strings: [String: StringEntry]
            let version: String
        }
        
        let xcstrings = try decoder.decode(XCStringsContainer.self, from: data)
        
        return xcstrings.strings.map { key, entry in
            var translations: [String: String] = [:]
            
            for (languageCode, localization) in entry.localizations {
                translations[languageCode] = localization.stringUnit.value
            }
            
            return TranslationItem(
                key: key,
                translations: translations,
                comment: entry.comment ?? ""
            )
        }
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