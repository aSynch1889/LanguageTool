import Foundation

enum PlatformType: String, CaseIterable, Sendable {
    case iOS = "iOS"
    case flutter = "Flutter"
    case electron = "Electron"
    
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
