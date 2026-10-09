import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppShellView: View {
    @StateObject private var shell = AppShellViewModel()
    @StateObject private var transferViewModel = TransferViewModel()
    @StateObject private var masterViewModel = LocalizationMasterViewModel()
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    /// Bumped after each appearance apply so the whole shell remounts with a fresh colorScheme.
    @State private var appearanceEpoch = 0
    @State private var languageEpoch = 0
    @State private var resolvedScheme: ColorScheme = .light

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
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(ThemeSurface.page(for: resolvedScheme))
        } detail: {
            detailBody
                .background(ThemeSurface.page(for: resolvedScheme))
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
                            selectAppearance(mode)
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
                    Label(
                        "Appearance".localized,
                        systemImage: resolvedScheme == .dark ? "moon.fill" : "sun.max"
                    )
                }
                .help("Appearance".localized)
            }
        }
        // Always pass an *explicit* ColorScheme. `nil` (system) leaves children stuck after dark.
        .preferredColorScheme(resolvedScheme)
        .environment(\.colorScheme, resolvedScheme)
        .id("\(appearanceEpoch)-\(languageEpoch)")
        .environmentObject(shell)
        .onAppear {
            AppearanceMode.migrateIfNeeded()
            if UserDefaults.standard.string(forKey: AppearanceMode.storageKey) == nil {
                appearanceModeRaw = AppearanceMode.system.rawValue
            }
            // Apply scheme only — remounting here would change `.id` and re-trigger onAppear forever.
            refreshAppearance(storeRaw: false, remount: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppearanceMode.systemThemeChangedNotification)) { _ in
            guard appearanceMode == .system else { return }
            refreshAppearance(storeRaw: false, remount: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            if let language = UserDefaults.standard.string(forKey: "appLanguage") {
                LocalizationManager.shared.setLanguage(language)
            }
            languageEpoch &+= 1
        }
        .onChange(of: shell.pendingReview) { _, request in
            guard let request else { return }
            Task { @MainActor in
                await masterViewModel.loadForReview(
                    path: request.path,
                    platform: request.platform,
                    languageCodes: request.languageCodes,
                    skipExisting: request.skipExisting
                )
                shell.clearPendingReview()
            }
        }
    }

    private func selectAppearance(_ mode: AppearanceMode) {
        mode.applyToApp()
        appearanceModeRaw = mode.rawValue
        resolvedScheme = mode.resolvedColorScheme()
        appearanceEpoch &+= 1
    }

    private func refreshAppearance(storeRaw: Bool, remount: Bool) {
        let mode = appearanceMode
        mode.applyToApp()
        if storeRaw {
            appearanceModeRaw = mode.rawValue
        }
        let nextScheme = mode.resolvedColorScheme()
        if resolvedScheme != nextScheme {
            resolvedScheme = nextScheme
        }
        if remount {
            appearanceEpoch &+= 1
        }
    }

    private var sidebarSelection: Binding<AppShellViewModel.SidebarItem?> {
        Binding(
            get: { shell.sidebar },
            set: { newValue in
                guard let newValue, newValue != shell.sidebar else { return }
                // List selection mutates during a view update — defer publishes to the next turn.
                Task { @MainActor in
                    await selectSidebar(newValue)
                }
            }
        )
    }

    @MainActor
    private func selectSidebar(_ newValue: AppShellViewModel.SidebarItem) async {
        if shell.sidebar == .review && newValue != .review {
            guard masterViewModel.confirmCloseIfNeeded() else { return }
        }
        guard shell.sidebar != newValue else { return }
        shell.sidebar = newValue
    }

    @ViewBuilder
    private var detailBody: some View {
        // Keep both panes alive so tab switches don't remount and re-publish child state.
        ZStack {
            TransferView(viewModel: transferViewModel)
                .opacity(shell.sidebar == .transfer ? 1 : 0)
                .allowsHitTesting(shell.sidebar == .transfer)
                .accessibilityHidden(shell.sidebar != .transfer)

            LocalizationMasterView(
                viewModel: masterViewModel,
                onGoToConvert: {
                    Task { @MainActor in
                        await selectSidebar(.transfer)
                    }
                },
                onOpenFile: { presentOpenPanelForReview() }
            )
            .opacity(shell.sidebar == .review ? 1 : 0)
            .allowsHitTesting(shell.sidebar == .review)
            .accessibilityHidden(shell.sidebar != .review)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
