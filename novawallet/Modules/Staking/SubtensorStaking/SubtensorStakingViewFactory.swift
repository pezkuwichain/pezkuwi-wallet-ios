import Foundation
import UIKit
import Foundation_iOS

enum SubtensorStakingViewFactory {
    /// Assembles the TAO staking dashboard VIPER module.
    ///
    /// - Parameters:
    ///   - chainAsset: Bittensor chain + asset (needed for fee and amount formatting).
    ///   - coldkey: The user's account ID (coldkey in Bittensor terminology).
    static func createView(chainAsset: ChainAsset, coldkey: AccountId) -> SubtensorStakingViewController {
        let delegatesClient = BittensorDelegatesClient()

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

        let localizationManager = LocalizationManager.shared

        let interactor = SubtensorStakingInteractor(service: service)
        let wireframe = SubtensorStakingWireframe(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        )
        let presenter = SubtensorStakingPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset
        )
        let view = SubtensorStakingViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
