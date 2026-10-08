import SwiftUI

@main
struct LanguageToolApp: App {
    init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") {
            LocalizationManager.shared.setLanguage(savedLanguage)
        } else {
            UserDefaults.standard.set("en", forKey: "appLanguage")
            LocalizationManager.shared.setLanguage("en")
        }

        AppearanceMode.migrateIfNeeded()

        // Ensure provider registry is initialized before UI binds to it.
        _ = AIProviderRegistry.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                    if let language = UserDefaults.standard.string(forKey: "appLanguage") {
                        LocalizationManager.shared.setLanguage(language)
                    }
                }
        }
        .defaultSize(width: 1000, height: 700)

        Settings {
            SettingsView()
        }
    }
}
