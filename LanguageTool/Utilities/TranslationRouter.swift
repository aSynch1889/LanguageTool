import Foundation

enum TranslationRouteReason: Equatable {
    case keepPrimary
    case largeBatchUsesMT
}

struct TranslationRouteDecision: Equatable {
    let preferredProviderId: String
    let reason: TranslationRouteReason
}

enum TranslationRouter {
    /// Batches at or above this size prefer a dedicated MT provider when available.
    static let largeBatchThreshold = 40

    static func decide(
        batchCount: Int,
        primaryProviderId: String,
        mtProviderId: String = "aliyun",
        mtAvailable: Bool
    ) -> TranslationRouteDecision {
        if batchCount >= largeBatchThreshold,
           mtAvailable,
           primaryProviderId != mtProviderId {
            return TranslationRouteDecision(
                preferredProviderId: mtProviderId,
                reason: .largeBatchUsesMT
            )
        }
        return TranslationRouteDecision(
            preferredProviderId: primaryProviderId,
            reason: .keepPrimary
        )
    }
}
