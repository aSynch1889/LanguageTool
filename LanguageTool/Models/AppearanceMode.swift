import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System".localized
        case .light: return "Light".localized
        case .dark: return "Dark".localized
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// AppKit appearance — materials and NSColor resolve against this.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static let storageKey = "appearanceMode"
    static let legacyDarkModeKey = "isDarkMode"

    /// Migrates legacy `isDarkMode` once: true → dark, false → system.
    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: storageKey) == nil else { return }
        if defaults.object(forKey: legacyDarkModeKey) != nil {
            let mode: AppearanceMode = defaults.bool(forKey: legacyDarkModeKey) ? .dark : .system
            defaults.set(mode.rawValue, forKey: storageKey)
        } else {
            defaults.set(AppearanceMode.system.rawValue, forKey: storageKey)
        }
    }

    static func load(defaults: UserDefaults = .standard) -> AppearanceMode {
        migrateIfNeeded(defaults: defaults)
        let raw = defaults.string(forKey: storageKey) ?? AppearanceMode.system.rawValue
        return AppearanceMode(rawValue: raw) ?? .system
    }

    /// Keep SwiftUI `preferredColorScheme` and AppKit `NSApp.appearance` in sync.
    /// Switching dark → system via `preferredColorScheme(nil)` alone often leaves materials stuck dark.
    func applyToApp() {
        NSApp.appearance = nsAppearance
    }
}
