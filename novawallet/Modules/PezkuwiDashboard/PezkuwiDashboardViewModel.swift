import Foundation

/// Presentation model — mirrors Android's `PezkuwiDashboardModel`
/// (`presentation/balance/list/model/PezkuwiDashboardModel.kt`).
struct PezkuwiDashboardViewModel {
    let roles: [String]
    let trustScore: String
    let welatiCount: String
    let citizenshipStatus: PezkuwiCitizenshipStatus
    let isTrackingScore: Bool
}

/// Which action buttons are visible/enabled for a given citizenship status — mirrors Android's
/// `PezkuwiDashboardHolder.bindButtons(status:)` exactly.
struct PezkuwiDashboardButtonsState {
    let applyTitleIsApprove: Bool
    let signVisible: Bool
    let signEnabled: Bool
    let shareEnabled: Bool

    init(citizenshipStatus: PezkuwiCitizenshipStatus) {
        if citizenshipStatus == .approved {
            // Citizen: primary button becomes "Approve Referral", sign hidden, share always enabled.
            applyTitleIsApprove = true
            signVisible = false
            signEnabled = false
            shareEnabled = true
        } else {
            // Not yet a citizen: all three buttons are visible; sign only enabled once the
            // referrer approved the application; share stays visible but dimmed/disabled.
            applyTitleIsApprove = false
            signVisible = true
            signEnabled = citizenshipStatus == .referrerApproved
            shareEnabled = false
        }
    }
}
