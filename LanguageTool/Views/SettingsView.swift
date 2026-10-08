import SwiftUI

struct SettingsView: View {
    @ObservedObject private var providerManager = AIProviderManager.shared
    @ObservedObject private var providerRegistry = AIProviderRegistry.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @AppStorage("translationGlossary") private var translationGlossary: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

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

    @State private var languageChanged = false
    @State private var glossaryDroppedLines = 0

    @Environment(\.colorScheme) var colorScheme

    private var glossaryValidation: (entries: [GlossaryEntry], droppedLines: Int) {
        GlossaryStore.validate(translationGlossary)
    }

    var body: some View {
        Form {
            Section(header: Text("API Settings".localized)) {
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
                .onChange(of: appLanguage) { _, newValue in
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    UserDefaults.standard.synchronize()
                    NotificationCenter.default.post(name: .languageChanged, object: nil)
                    languageChanged.toggle()
                }

                Text("Language changes may require restarting the app.".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Appearance Settings".localized)) {
                Toggle("Dark Mode".localized, isOn: $isDarkMode)
            }

            Section(header: Text("Notification Settings".localized)) {
                Toggle("Enable Notifications".localized, isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
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
                    .onChange(of: translationGlossary) { _, newValue in
                        let validation = GlossaryStore.validate(newValue)
                        glossaryDroppedLines = validation.droppedLines
                        // Persist through AppStorage; GlossaryStore reads same key.
                    }

                Text("One rule per line, e.g. iPhone => iPhone".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Parsed entries: \(glossaryValidation.entries.count)/\(GlossaryStore.maxEntries)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if glossaryValidation.droppedLines > 0 {
                    Text("Ignored invalid/oversized lines: \(glossaryValidation.droppedLines)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 20)
        .frame(width: 400)
        .frame(minHeight: 200)
        .id(languageChanged)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            notificationManager.initializeDefaultSettings()
            notificationsEnabled = notificationManager.areNotificationsEnabled
        }
    }

    private func requestNotificationPermission() async {
        let granted = await notificationManager.requestPermission()
        if !granted {
            await MainActor.run {
                notificationsEnabled = false
                notificationManager.areNotificationsEnabled = false
            }
        }
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("com.app.languageChanged")
}
