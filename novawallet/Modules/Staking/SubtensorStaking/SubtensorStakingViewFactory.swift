import Foundation
import UIKit

enum SubtensorStakingViewFactory {
    /// Assembles the SubtensorStaking VIPER module. Returns a ready-to-
    /// present UIViewController wired to the stubbed service layer.
    ///
    /// `coldkey` is required (no default) so the Task 21 integration site
    /// is forced to name what account it's passing. A zero-AccountId
    /// placeholder at the call site is still permitted as a first-pass
    /// integration — it just can't be accidentally inherited.
    static func createView(coldkey: AccountId) -> SubtensorStakingViewController {
        let delegatesClient = BittensorDelegatesClient()

        // [TEMP-TAOSTATS] Phase B temporary numeric data source. Swap for a
        // Nova-indexer implementation when infra ships Bittensor support.
        let dataSource: SubtensorValidatorDataSourceProtocol = {
            if let key = TaoStatsKeyProvider.loadKey() {
                return TaoStatsValidatorDataSource(apiKey: key, session: .shared)
            } else {
                return StubSubtensorValidatorDataSource()
            }
        }()

        let validatorProvider = SubtensorValidatorProvider(
            delegatesClient: delegatesClient,
            dataSource: dataSource
        )
        let service = SubtensorStakingService(
            validatorProvider: validatorProvider,
            selectedColdkey: coldkey
        )

        let interactor = SubtensorStakingInteractor(service: service)
        let wireframe = SubtensorStakingWireframe()
        let presenter = SubtensorStakingPresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        let view = SubtensorStakingViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
