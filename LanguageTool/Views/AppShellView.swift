import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppShellView: View {
    @StateObject private var shell = AppShellViewModel()
    @StateObject private var masterViewModel = LocalizationMasterViewModel()
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private let supportedLanguages: [(code: String, name: String)] = [
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

    var body: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(AppShellViewModel.SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }

                Section {
                    SettingsLink {
                        Label("Settings…".localized, systemImage: "gearshape")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
            .listStyle(.sidebar)
        } detail: {
            detailBody
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings".localized, systemImage: "gearshape")
                }
                .help("Settings".localized)

                Menu {
                    ForEach(supportedLanguages, id: \.code) { item in
                        Button(item.name) {
                            appLanguage = item.code
                            UserDefaults.standard.set([item.code], forKey: "AppleLanguages")
                            LocalizationManager.shared.setLanguage(item.code)
                            NotificationCenter.default.post(name: .languageChanged, object: nil)
                        }
                    }
                } label: {
                    Label("Language".localized, systemImage: "globe")
                }
                .help("Interface Language".localized)

                Menu {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            appearanceModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                if mode == appearanceMode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Appearance".localized, systemImage: appearanceMode == .dark ? "moon.fill" : "sun.max")
                }
                .help("Appearance".localized)
            }
        }
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .id(appearanceModeRaw) // Force remount so materials / semantic colors refresh after dark → system.
        .environmentObject(shell)
        .onAppear {
            AppearanceMode.migrateIfNeeded()
            if UserDefaults.standard.string(forKey: AppearanceMode.storageKey) == nil {
                appearanceModeRaw = AppearanceMode.system.rawValue
            }
            appearanceMode.applyToApp()
        }
        .onChange(of: appearanceModeRaw) { _, _ in
            appearanceMode.applyToApp()
        }
        .onChange(of: shell.pendingReview) { _, request in
            guard let request else { return }
            Task {
                await masterViewModel.loadForReview(
                    path: request.path,
                    platform: request.platform,
                    languageCodes: request.languageCodes,
                    skipExisting: request.skipExisting
                )
            }
        }
    }

    private var sidebarSelection: Binding<AppShellViewModel.SidebarItem?> {
        Binding(
            get: { shell.sidebar },
            set: { newValue in
                guard let newValue else { return }
                if shell.sidebar == .review && newValue != .review {
                    guard masterViewModel.confirmCloseIfNeeded() else { return }
                }
                shell.sidebar = newValue
            }
        )
    }

    @ViewBuilder
    private var detailBody: some View {
        switch shell.sidebar {
        case .transfer:
            TransferView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review:
            LocalizationMasterView(
                viewModel: masterViewModel,
                onGoToConvert: { shell.goToTransfer() },
                onOpenFile: { presentOpenPanelForReview() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func presentOpenPanelForReview() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "xcstrings") ?? .json,
            UTType(filenameExtension: "strings") ?? .text,
            UTType(filenameExtension: "arb") ?? .json,
            .json
        ]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let platform = platformGuess(for: url)
        shell.requestReview(
            AppShellViewModel.ReviewRequest(
                path: url.path,
                platform: platform,
                languageCodes: [],
                skipExisting: true
            )
        )
    }

    private func platformGuess(for url: URL) -> PlatformType {
        switch url.pathExtension.lowercased() {
        case "arb":
            return .flutter
        case "json":
            return .electron
        default:
            return .iOS
        }
    }
}
