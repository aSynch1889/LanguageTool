import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("selectedAIService") private var selectedService: AIServiceType = .deepseek
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("aliyunApiKey") private var aliyunApiKey: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "en"  // 默认为英语
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false // 添加暗黑模式存储
    
    // 修改为使用原生语言名称
    private let supportedLanguages = [
        ("en", "English"),
        ("en-CA", "English (Canada)"),
        ("en-GB", "English (UK)"),
        ("en-IN", "English (India)"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語"),
        ("ko", "한국어")
    ]
    
    // 添加语言切换通知
    @State private var languageChanged = false
    
    @Environment(\.colorScheme) var colorScheme // 获取当前颜色方案

    var body: some View {
        Form {
            Section(header: Text("API Settings".localized)) {
                // AI 服务选择
                Picker("AI Service".localized, selection: $selectedService) {
                    ForEach(AIServiceType.allCases, id: \.self) { service in
                        Text(service.description).tag(service)
                    }
                }
                
                switch selectedService {
                case .deepseek:
                    SecureField("DeepSeek API Key".localized, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                case .gemini:
                    SecureField("Gemini API Key".localized, text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                case .aliyun:
                    SecureField("Aliyun API Key".localized, text: $aliyunApiKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Section(header: Text("Language Settings".localized)) {
                Picker("Interface Language".localized, selection: $appLanguage) {
                    ForEach(supportedLanguages, id: \.0) { code, nativeName in
                        Text(nativeName).tag(code)
                    }
                }
                .onChange(of: appLanguage) { oldValue, newValue in
                    // 更新语言设置
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    UserDefaults.standard.synchronize()
                    
                    // 发送语言变更通知
                    NotificationCenter.default.post(name: .languageChanged, object: nil)
                    languageChanged.toggle()
                }
            }
            
            Section(header: Text("Appearance Settings".localized)) { // 添加外观设置部分
                Toggle("Dark Mode".localized, isOn: $isDarkMode) // 暗黑模式切换
            }
            
            Section("Other Settings".localized) {
                Text("More Settings Under Development...".localized)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 20)
        .frame(width: 400)
        .frame(minHeight: 200)
        .id(languageChanged) // 强制视图刷新
        .preferredColorScheme(isDarkMode ? .dark : .light) // 根据 isDarkMode 设置颜色方案
    }
}

// 添加语言变更通知名称
extension Notification.Name {
    static let languageChanged = Notification.Name("com.app.languageChanged")
} 
