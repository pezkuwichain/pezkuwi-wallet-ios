import Foundation
import UIKit

protocol SubtensorStakingViewProtocol: AnyObject {
    var controller: UIViewController { get }

    /// Replaces the screen contents with the dashboard (stake card,
    /// actions, validators, info). The view derives its loading / empty
    /// state from the contents of the view model — there is no separate
    /// status channel.
    func didReceive(viewModel: SubtensorStakingDashboardViewModel)
}

protocol SubtensorStakingInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol SubtensorStakingInteractorOutputProtocol: AnyObject {
    func didReceive(positions: [SubtensorStakePosition])
    func didReceive(error: Error)
}

protocol SubtensorStakingPresenterProtocol: AnyObject {
    func setup()
    /// Re-fetches positions without rebuilding the screen. Used on
    /// viewWillAppear so popping back from a stake confirm flow shows
    /// the new position immediately.
    func refresh()
    func didTapStakeMore()
    func didTapUnstake()
}

protocol SubtensorStakingWireframeProtocol: AnyObject {
    /// Stake type → setup → confirm flow (existing behaviour).
    func showStakingFlow(from view: UIViewController)

    /// Placeholder until the unstake form ships — surfaces a "Coming soon"
    /// alert. We keep this routed through the wireframe (instead of just
    /// showing the alert from the presenter) so swapping in the real flow
    /// later is a one-file change.
    func showUnstakeComingSoon(from view: UIViewController)

    func showError(from view: UIViewController, message: String)
}
