import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS
import UIKit

// Temporary bypass: skip staking info screen, go directly to stake setup
// with a pre-selected collator. The info screen is blocked on offchain
// indexer data that doesn't exist yet.
// Remove this class when the subquery staking indexer ships for EWX.
private final class ParachainAvnInfoBypassViewController: UIViewController, StartStakingInfoViewProtocol {
    let state: ParachainStakingSharedStateProtocol
    private var didNavigate = false

    // First active EWX collator — used to pre-populate the collator field
    private static let defaultCollatorId = "5CQKcj9mwmRzr1XTUi6htKVELUDZkD8UxN4nsN27b3niaPDe"

    var isSetup: Bool { true }

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didNavigate else { return }
        didNavigate = true

        guard let setupView = ParaStkStakeSetupViewFactory.createView(
            with: state,
            initialDelegator: nil,
            initialScheduledRequests: nil,
            delegationIdentities: nil
        ) else { return }

        let setupController = setupView.controller
        navigationController?.pushViewController(setupController, animated: false)

        // Pre-select a known EWX collator so the user can submit immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let vc = setupController as? CollatorStakingSetupViewController,
                  let presenter = vc.presenter as? ParaStkStakeSetupPresenter else {
                return
            }
            let address = DisplayAddress(
                address: Self.defaultCollatorId,
                username: "EWX Collator"
            )
            presenter.changeCollator(with: address)
        }
    }

    func didReceive(viewModel _: LoadableViewModelState<StartStakingViewModel>) {}
    func didReceive(balance _: String) {}
}

extension StartStakingInfoViewFactory {
    static func createParachainAvnView(
        for stakingOption: Multistaking.ChainAssetOption
    ) -> StartStakingInfoViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let stateFactory = StakingSharedStateFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            delegatedAccountSyncService: nil,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        guard
            let state = try? stateFactory.createParachainAvn(for: stakingOption),
            CurrencyManager.shared != nil else {
            return nil
        }

        // Bypass the info screen — go directly to stake setup
        return ParachainAvnInfoBypassViewController(state: state)
    }

    private static func createParachainAvnInteractor(
        state: ParachainStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingParachainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let stakingDurationFactory = ParachainAvnDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: state.stakingOption.chainAsset.chain)
        )

        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StartStakingParachainInteractor(
            state: state,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            currencyManager: currencyManager,
            networkInfoFactory: ParachainAvnNetworkInfoOperationFactory(),
            durationOperationFactory: stakingDurationFactory,
            sharedOperation: state.startSharedOperation(),
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared
        )
    }
}
