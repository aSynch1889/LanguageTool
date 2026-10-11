import Foundation
import SwiftUI

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
    @Published var toastMessage: String?

    private var toastClearTask: Task<Void, Never>?

    func requestReview(_ request: ReviewRequest) {
        pendingReview = request
        if sidebar != .review {
            sidebar = .review
        }
    }

    func clearPendingReview() {
        guard pendingReview != nil else { return }
        pendingReview = nil
    }

    func goToTransfer() {
        guard sidebar != .transfer else { return }
        sidebar = .transfer
    }

    func showToast(_ message: String, duration: TimeInterval = 2.5) {
        toastClearTask?.cancel()
        toastMessage = message
        toastClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
