import Foundation
import BigInt

/// Mirrors the Android sibling app's `CitizenshipStatus` (`presentation/citizenship/CitizenshipStatus.kt`).
/// Backed by the `IdentityKyc.KycStatuses` storage item on the Pezkuwi People chain.
enum PezkuwiCitizenshipStatus: Equatable {
    case notStarted
    case pendingReferral
    case referrerApproved
    case approved

    init(remoteVariantName: String?) {
        switch remoteVariantName {
        case "PendingReferral":
            self = .pendingReferral
        case "ReferrerApproved":
            self = .referrerApproved
        case "Approved":
            self = .approved
        default:
            self = .notStarted
        }
    }
}

/// Mirrors the Android sibling app's `PezkuwiDashboardData`
/// (`feature-assets/.../data/model/PezkuwiDashboardData.kt`).
struct PezkuwiDashboardData {
    static let nonCitizenRole = "Non-Citizen"

    let roles: [String]
    let trustScore: BigUInt
    let welatiCount: Int
    let citizenshipStatus: PezkuwiCitizenshipStatus
    let isTrackingScore: Bool

    init(
        roles: [String],
        trustScore: BigUInt,
        welatiCount: Int,
        citizenshipStatus: PezkuwiCitizenshipStatus = .notStarted,
        isTrackingScore: Bool = false
    ) {
        self.roles = roles.isEmpty ? [Self.nonCitizenRole] : roles
        self.trustScore = trustScore
        self.welatiCount = welatiCount
        self.citizenshipStatus = citizenshipStatus
        self.isTrackingScore = isTrackingScore
    }
}
