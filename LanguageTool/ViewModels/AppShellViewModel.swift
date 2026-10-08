import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppShellViewModel: ObservableObject {
    enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
        case transfer
        case review

        var id: String { rawValue }

        var title: String {
            switch self {
            case .transfer: return "Convert".localized
            case .review: return "Review".localized
            }
        }

        var systemImage: String {
            switch self {
            case .transfer: return "arrow.left.arrow.right"
            case .review: return "tablecells"
            }
        }
    }

    struct ReviewRequest: Equatable {
        let path: String
        let platform: PlatformType
        let languageCodes: [String]
        let skipExisting: Bool
    }

    @Published var sidebar: SidebarItem = .transfer
    @Published var pendingReview: ReviewRequest?

    func requestReview(_ request: ReviewRequest) {
        pendingReview = request
        sidebar = .review
    }

    func goToTransfer() {
        sidebar = .transfer
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
