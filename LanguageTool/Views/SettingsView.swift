import SwiftUI

struct SettingsView: View {
    @ObservedObject private var providerManager = AIProviderManager.shared
    @ObservedObject private var providerRegistry = AIProviderRegistry.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @AppStorage("translationGlossary") private var translationGlossary: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { newValue in
                newValue.applyToApp()
                appearanceModeRaw = newValue.rawValue
                // Mirror shell behavior: force an explicit scheme into the Settings window too.
                // (Settings is a separate scene; preferredColorScheme below reads storage.)
            }
        )
    }

    private var settingsResolvedScheme: ColorScheme {
        (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).resolvedColorScheme()
    }

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
    @State private var isTestingConnection = false
    @State private var connectionTestMessage: String?
    @State private var connectionTestSucceeded = false
    @FocusState private var focusedEndpointField: EndpointField?

    private enum EndpointField: Hashable {
        case model
        case baseURL
    }

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
                    connectionTestMessage = nil
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

                ForEach(providerManager.providersNeedingVisibleKeys()) { provider in
                    let apiKeyBinding = Binding<String>(
                        get: { providerManager.getApiKey(for: provider.id) },
                        set: { providerManager.setApiKey($0, for: provider.id) }
                    )
                    SecureField("\(provider.displayName) API Key".localized, text: apiKeyBinding)
                        .textFieldStyle(.roundedBorder)
                }

                if let selectedProvider = providerManager.getSelectedProvider() {
                    TextField("Model".localized, text: $providerManager.modelDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedEndpointField, equals: .model)
                        .onSubmit { providerManager.commitModelDraft() }

                    TextField("Base URL".localized, text: $providerManager.baseURLDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedEndpointField, equals: .baseURL)
                        .onSubmit { providerManager.commitBaseURLDraft() }
                        .autocorrectionDisabled()
#if os(macOS)
                        .textSelection(.enabled)
#endif

                    if selectedProvider.requiresCustomEndpoint || selectedProvider.id == "openai_compatible" {
                        Text("Replace the whole Base URL (e.g. https://api.deepseek.com). It normalizes when you leave the field or press Return.".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Button(isTestingConnection ? "Testing…".localized : "Test Connection".localized) {
                            Task { await runConnectionTest() }
                        }
                        .disabled(isTestingConnection)

                        if let connectionTestMessage {
                            Text(connectionTestMessage)
                                .font(.caption)
                                .foregroundColor(connectionTestSucceeded ? .green : .red)
                                .lineLimit(2)
                        }
                    }
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
                Picker("Appearance".localized, selection: appearanceModeBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
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
        .frame(width: 420)
        .frame(minHeight: 200)
        .id(languageChanged)
        .preferredColorScheme(settingsResolvedScheme)
        .environment(\.colorScheme, settingsResolvedScheme)
        .onAppear {
            AppearanceMode.migrateIfNeeded()
            (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).applyToApp()
            notificationManager.initializeDefaultSettings()
            notificationsEnabled = notificationManager.areNotificationsEnabled
            providerManager.refreshEndpointDrafts()
        }
        .onChange(of: focusedEndpointField) { oldValue, newValue in
            // Commit only when leaving the field — never rewrite while typing.
            if oldValue == .model && newValue != .model {
                providerManager.commitModelDraft()
            }
            if oldValue == .baseURL && newValue != .baseURL {
                providerManager.commitBaseURLDraft()
            }
        }
        .onDisappear {
            providerManager.commitModelDraft()
            providerManager.commitBaseURLDraft()
        }
    }

    private func runConnectionTest() async {
        await MainActor.run {
            providerManager.commitModelDraft()
            providerManager.commitBaseURLDraft()
            isTestingConnection = true
            connectionTestMessage = nil
        }
        do {
            let reply = try await AIServiceV2.shared.testConnection()
            await MainActor.run {
                connectionTestSucceeded = true
                connectionTestMessage = "Connected".localized + ": \(reply.prefix(40))"
                isTestingConnection = false
            }
        } catch {
            await MainActor.run {
                connectionTestSucceeded = false
                connectionTestMessage = error.localizedDescription
                isTestingConnection = false
            }
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
