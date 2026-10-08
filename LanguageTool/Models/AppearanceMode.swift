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

    /// AppKit appearance — must be applied *before* SwiftUI remounts after a mode change.
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

    /// Apply AppKit appearance to the shared app **and every window** before SwiftUI updates.
    /// `NSApp` is nil during early `App.init` — those calls no-op safely.
    @MainActor
    func applyToApp() {
        guard let app = NSApp else { return }
        let appearance = nsAppearance
        app.appearance = appearance
        for window in app.windows {
            window.appearance = appearance
        }
    }
}

// MARK: - Scheme-driven fills (do not use sticky NSColor / Material)

enum ThemeSurface {
    /// Card / panel fill that follows SwiftUI `colorScheme`, not AppKit dynamic colors.
    static func card(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.17, green: 0.17, blue: 0.19)
        case .light:
            fallthrough
        @unknown default:
            return Color(red: 0.96, green: 0.96, blue: 0.975)
        }
    }

    static func inset(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .light:
            fallthrough
        @unknown default:
            return Color(red: 1.0, green: 1.0, blue: 1.0)
        }
    }
}
