import Foundation

enum PlatformType: String, CaseIterable, Sendable {
    case iOS = "iOS"
    case flutter = "Flutter"
    case electron = "Electron"
    
    /// Short label for compact pickers (e.g. segmented control).
    var shortName: String { rawValue }

    /// File-format hint shown under the platform picker.
    var formatHint: String {
        switch self {
        case .iOS:
            return ".strings / .xcstrings"
        case .flutter:
            return ".arb"
        case .electron:
            return ".json"
        }
    }

    var description: String {
        switch self {
        case .iOS:
            return "iOS (.strings/.xcstrings)"
        case .flutter:
            return "Flutter (.arb)"
        case .electron:
            return "Electron (.json)"
        }
    }
    
    var fileTypes: [String] {
        switch self {
        case .iOS:
            return ["strings", "xcstrings"]
        case .flutter:
            return ["arb"]
        case .electron:
            return ["json"]
        }
    }
} 
