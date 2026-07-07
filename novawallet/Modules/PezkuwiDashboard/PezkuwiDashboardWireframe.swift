import Foundation

final class PezkuwiDashboardWireframe: PezkuwiDashboardWireframeProtocol {
    // NOTE: the full native "apply for citizenship / sign / approve referral" flow (equivalent of
    // Android's `CitizenshipBottomSheet` + `CitizenshipViewModel`, ~265 lines with its own
    // multi-field application form, extrinsic submission and pending-referral-approval list) is a
    // distinct, sizeable feature that was intentionally NOT built as part of this dashboard-card
    // pass — only the card's own data/UI was requested. This is a deliberate scope cut, flagged in
    // the delivery summary, not an oversight.
    func showCitizenshipApplication(from view: PezkuwiDashboardViewProtocol?) {
        present(
            message: "Citizenship application is coming soon.",
            title: "Pezkuwi Citizenship",
            closeAction: "Close",
            from: view
        )
    }
}
