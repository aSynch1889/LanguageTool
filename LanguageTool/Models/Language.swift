import Foundation

enum LanguageCategory: String, CaseIterable {
    case all = "all"
    case common = "common"
    case asian = "asian"
    case european = "european"
    case american = "american"
    case african = "african"

    var displayName: String {
        switch self {
        case .all: return "All Languages"
        case .common: return "Common"
        case .asian: return "Asian"
        case .european: return "European"
        case .american: return "American"
        case .african: return "African"
        }
    }
}

struct Language: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let localizedName: String
    let category: LanguageCategory
    
    // 支持 Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
    
    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.code == rhs.code
    }
    
    // Xcode 支持的完整语言列表
    static let supportedLanguages: [Language] = [
        // 中文
        Language(code: "zh-Hans", name: "Chinese, Simplified", localizedName: "简体中文", category: .common),
        Language(code: "zh-Hant", name: "Chinese, Traditional", localizedName: "繁體中文", category: .asian),
        Language(code: "zh-HK", name: "Chinese, Hong Kong", localizedName: "繁體中文（香港）", category: .asian),

        // 英语变体
        Language(code: "en", name: "English", localizedName: "English", category: .common),
        Language(code: "en-AU", name: "English, Australia", localizedName: "English (Australia)", category: .american),
        Language(code: "en-GB", name: "English, UK", localizedName: "English (UK)", category: .european),
        Language(code: "en-IN", name: "English, India", localizedName: "English (India)", category: .asian),
        Language(code: "en-CA", name: "English, Canada", localizedName: "English (Canada)", category: .american),
        
        // 欧洲语言
        Language(code: "fr", name: "French", localizedName: "Français", category: .common),
        Language(code: "fr-CA", name: "French, Canada", localizedName: "Français (Canada)", category: .american),
        Language(code: "es", name: "Spanish", localizedName: "Español", category: .common),
        Language(code: "es-419", name: "Spanish, Latin America", localizedName: "Español (Latinoamérica)", category: .american),
        Language(code: "de", name: "German", localizedName: "Deutsch", category: .common),
        Language(code: "it", name: "Italian", localizedName: "Italiano", category: .european),
        Language(code: "pt", name: "Portuguese", localizedName: "Português", category: .european),
        Language(code: "pt-BR", name: "Portuguese, Brazil", localizedName: "Português (Brasil)", category: .american),
        Language(code: "pt-PT", name: "Portuguese, Portugal", localizedName: "Português (Portugal)", category: .european),
        Language(code: "ru", name: "Russian", localizedName: "Русский", category: .european),
        Language(code: "pl", name: "Polish", localizedName: "Polski", category: .european),
        Language(code: "tr", name: "Turkish", localizedName: "Türkçe", category: .european),
        Language(code: "nl", name: "Dutch", localizedName: "Nederlands", category: .european),
        Language(code: "sv", name: "Swedish", localizedName: "Svenska", category: .european),
        Language(code: "da", name: "Danish", localizedName: "Dansk", category: .european),
        Language(code: "fi", name: "Finnish", localizedName: "Suomi", category: .european),
        Language(code: "nb", name: "Norwegian Bokmål", localizedName: "Norsk bokmål", category: .european),
        Language(code: "el", name: "Greek", localizedName: "Ελληνικά", category: .european),
        Language(code: "cs", name: "Czech", localizedName: "Čeština", category: .european),
        Language(code: "hu", name: "Hungarian", localizedName: "Magyar", category: .european),
        Language(code: "sk", name: "Slovak", localizedName: "Slovenčina", category: .european),
        Language(code: "uk", name: "Ukrainian", localizedName: "Українська", category: .european),
        Language(code: "hr", name: "Croatian", localizedName: "Hrvatski", category: .european),
        Language(code: "ca", name: "Catalan", localizedName: "Català", category: .european),
        Language(code: "ro", name: "Romanian", localizedName: "Română", category: .european),
        Language(code: "he", name: "Hebrew", localizedName: "עברית", category: .asian),
        
        // 亚洲语言
        Language(code: "ja", name: "Japanese", localizedName: "日本語", category: .common),
        Language(code: "ko", name: "Korean", localizedName: "한국어", category: .common),
        Language(code: "th", name: "Thai", localizedName: "ไทย", category: .asian),
        Language(code: "vi", name: "Vietnamese", localizedName: "Tiếng Việt", category: .asian),
        Language(code: "hi", name: "Hindi", localizedName: "हिन्दी", category: .asian),
        Language(code: "bn", name: "Bengali", localizedName: "বাংলা", category: .asian),
        Language(code: "id", name: "Indonesian", localizedName: "Bahasa Indonesia", category: .asian),
        Language(code: "ms", name: "Malay", localizedName: "Bahasa Melayu", category: .asian),
        
        // 中东语言
        Language(code: "ar", name: "Arabic", localizedName: "العربية", category: .african),
        Language(code: "ar-SA", name: "Arabic, Saudi Arabia", localizedName: "العربية (السعودية)", category: .african),
        Language(code: "fa", name: "Persian", localizedName: "فارسی", category: .asian),
        Language(code: "ur", name: "Urdu", localizedName: "اردو", category: .asian),
        
        // 其他语言
        Language(code: "fil", name: "Filipino", localizedName: "Filipino", category: .asian),
        Language(code: "km", name: "Khmer", localizedName: "ខ្មែរ", category: .asian),
        Language(code: "mn", name: "Mongolian", localizedName: "Монгол", category: .asian),
        Language(code: "my", name: "Burmese", localizedName: "မြန်မာ", category: .asian),
        Language(code: "ne", name: "Nepali", localizedName: "नेपाली", category: .asian),
        Language(code: "si", name: "Sinhala", localizedName: "සිංහල", category: .asian),
        Language(code: "az", name: "Azerbaijani", localizedName: "Azərbaycan", category: .asian),
        Language(code: "kk", name: "Kazakh", localizedName: "Қазақ", category: .asian),
        Language(code: "hy", name: "Armenian", localizedName: "Հայերեն", category: .asian),
        Language(code: "ka", name: "Georgian", localizedName: "ქართული", category: .asian)
    ]

    // 便利方法
    static var commonLanguages: [Language] {
        supportedLanguages.filter { $0.category == .common }
    }

    static func languagesForCategory(_ category: LanguageCategory) -> [Language] {
        guard category != .all else { return supportedLanguages }
        return supportedLanguages.filter { $0.category == category }
    }

    static func searchLanguages(_ query: String) -> [Language] {
        guard !query.isEmpty else { return supportedLanguages }
        return supportedLanguages.filter { language in
            language.localizedName.localizedCaseInsensitiveContains(query) ||
            language.name.localizedCaseInsensitiveContains(query) ||
            language.code.localizedCaseInsensitiveContains(query)
        }
    }
} 
