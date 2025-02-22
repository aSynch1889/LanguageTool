import SwiftUI
import SwiftData

@main
struct LanguageToolApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
        .windowStyle(.hiddenTitleBar) // 隐藏默认标题栏
        .defaultSize(width: 600, height: 600) // 设置默认窗口大小
        
        // 添加设置窗口
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
    }
}
