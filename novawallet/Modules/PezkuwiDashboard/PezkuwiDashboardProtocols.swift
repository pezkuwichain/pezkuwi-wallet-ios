import Foundation
import UIKit
import UIKit_iOS
import SnapKit

// MARK: Module Interface
//
// Mirrors the `Banners` module's embedding contract (see `Modules/Banners/BannersProtocols.swift`):
// the Pezkuwi dashboard card is assembled as its own self-contained MVP module and embedded as a
// single cell inside `AssetList`, exactly like the banners widget is.

protocol PezkuwiDashboardModuleInputOwnerProtocol: AnyObject {
    var pezkuwiDashboardModule: PezkuwiDashboardModuleInputProtocol? { get set }
}

protocol PezkuwiDashboardModuleInputProtocol: AnyObject {
    var isAvailable: Bool { get }

    func refresh()
}

protocol PezkuwiDashboardModuleOutputProtocol: AnyObject {
    /// Called once the dashboard data is (un)available, e.g. no account exists for the
    /// Pezkuwi People chain yet — mirrors Android hiding the whole card in that case.
    func didReceivePezkuwiDashboard(available: Bool)

    /// Called whenever the card's own height changes (collapse/expand toggle, tracking button
    /// state change) so the host screen can re-layout the collection view.
    func didChangePezkuwiDashboardHeight()
}

protocol PezkuwiDashboardViewProviderProtocol: ControllerBackedProtocol {
    func getCardHeight() -> CGFloat
}

extension PezkuwiDashboardViewProviderProtocol {
    func setupPezkuwiDashboard(
        on parent: ControllerBackedProtocol?,
        view: UIView
    ) {
        guard
            let parentController = parent?.controller,
            let childView = controller.view
        else { return }

        parentController.addChild(controller)
        view.addSubview(childView)

        childView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        controller.didMove(toParent: parentController)
    }
}

// MARK: Inner Interfaces

protocol PezkuwiDashboardViewProtocol: ControllerBackedProtocol, PezkuwiDashboardViewProviderProtocol {
    func didReceive(viewModel: PezkuwiDashboardViewModel?)
    func didReceive(trackingLoading: Bool)
}

protocol PezkuwiDashboardPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func toggleExpanded()
    func applyClicked()
    func signClicked()
    func shareReferralClicked()
    func startTrackingClicked()
}

protocol PezkuwiDashboardInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func startTracking()
    func requestReferralAddress()
}

protocol PezkuwiDashboardInteractorOutputProtocol: AnyObject {
    func didReceive(dashboard: PezkuwiDashboardData?)
    func didStartTracking()
    func didReceiveTracking(error: Error)
    func didReceive(referralAddress: AccountAddress)
}

protocol PezkuwiDashboardWireframeProtocol: AnyObject, AlertPresentable, SharingPresentable {
    func showCitizenshipApplication(from view: PezkuwiDashboardViewProtocol?)
}
