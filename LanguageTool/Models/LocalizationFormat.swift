import Foundation

/// 本地化文件格式
enum LocalizationFormat: Sendable {
    /// Xcode Strings Catalog (.xcstrings)
    case xcstrings
    /// Strings File (.strings)
    case strings
    /// Flutter ARB File (.arb)
    case arb
    /// Electron JSON File (.json)
    case electron
} 
