import SwiftUI

struct SettingsView: View {
    @StateObject private var providerManager = AIProviderManager.shared
    @StateObject private var providerRegistry = AIProviderRegistry.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("translationGlossary") private var translationGlossary: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "en"  // 默认为英语
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false // 添加暗黑模式存储
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true // 通知开关
    
    // 修改为使用原生语言名称，与Localizable.xcstrings中的语言保持一致
    private let supportedLanguages = [
        ("en", "English"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("fr", "Français"),
        ("it", "Italiano"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("pt", "Português"),
        ("th", "ไทย"),
        ("tr", "Türkçe"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文")
    ]
    
    // 添加语言切换通知
    @State private var languageChanged = false
    
    @Environment(\.colorScheme) var colorScheme // 获取当前颜色方案

    var body: some View {
        Form {
            Section(header: Text("API Settings".localized)) {
                // AI 服务选择
                Picker("AI Service".localized, selection: $providerManager.selectedProviderId) {
                    ForEach(providerRegistry.allProviders()) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .onChange(of: providerManager.selectedProviderId) { _, newValue in
                    providerManager.setSelectedProvider(newValue)
                }

                Picker("Fallback AI Service".localized, selection: $providerManager.fallbackProviderId) {
                    Text("None".localized).tag("")
                    ForEach(providerRegistry.allProviders()) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .onChange(of: providerManager.fallbackProviderId) { _, newValue in
                    providerManager.setFallbackProvider(newValue)
                }

                // 动态生成API Key输入框
                if let selectedProvider = providerManager.getSelectedProvider() {
                    let apiKeyBinding = Binding<String>(
                        get: { providerManager.getApiKey(for: selectedProvider.id) },
                        set: { providerManager.setApiKey($0, for: selectedProvider.id) }
                    )

                    SecureField("\(selectedProvider.displayName) API Key".localized, text: apiKeyBinding)
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

            Section(header: Text("Notification Settings".localized)) {
                Toggle("Enable Notifications".localized, isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { oldValue, newValue in
                        if newValue {
                            // 当用户开启通知时，请求权限
                            Task {
                                await requestNotificationPermission()
                            }
                        }
                        notificationManager.areNotificationsEnabled = newValue
                    }

                Text("Receive notifications when translation tasks complete or fail".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Glossary".localized)) {
                TextEditor(text: $translationGlossary)
                    .frame(minHeight: 80, maxHeight: 120)
                    .font(.system(.body, design: .monospaced))
                Text("One rule per line, e.g. iPhone => iPhone".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .onAppear {
            notificationManager.initializeDefaultSettings()
            notificationsEnabled = notificationManager.areNotificationsEnabled
        }
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async {
        let granted = await notificationManager.requestPermission()
        if !granted {
            // 如果用户拒绝权限，关闭开关
            await MainActor.run {
                notificationsEnabled = false
                notificationManager.areNotificationsEnabled = false
            }
        }
    }
}

// 添加语言变更通知名称
extension Notification.Name {
    static let languageChanged = Notification.Name("com.app.languageChanged")
} 
