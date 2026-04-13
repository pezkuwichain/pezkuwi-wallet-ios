import Foundation
import Foundation_iOS

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol

    init(
        stateObserver: Observable<StakingDashboardModel>,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) {
        self.stateObserver = stateObserver
        self.delegatedAccountSyncService = delegatedAccountSyncService
    }

    func showMoreOptions(from view: ControllerBackedProtocol?) {
        guard let stakingMoreOptionsView = StakingMoreOptionsViewFactory.createView(stateObserver: stateObserver) else {
            return
        }

        stakingMoreOptionsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            stakingMoreOptionsView.controller,
            animated: true
        )
    }

    func showStakingDetails(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    ) {
        if option.type == .subtensor {
            showSubtensorStakingDetails(from: view, chainAsset: option.chainAsset)
            return
        }

        guard let detailsView = StakingMainViewFactory.createView(
            for: option,
            delegatedAccountSyncService: delegatedAccountSyncService
        ) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    private func showSubtensorStakingDetails(
        from view: StakingDashboardViewProtocol?,
        chainAsset: ChainAsset
    ) {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let accountResponse = wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        else { return }

        let coldkey = accountResponse.chainAccount.accountId
        let vc = SubtensorStakingViewFactory.createView(chainAsset: chainAsset, coldkey: coldkey)
        vc.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(vc, animated: true)
    }

    func showStartStaking(from view: StakingDashboardViewProtocol?, chainAsset: ChainAsset) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: chainAsset,
            selectedStakingType: nil
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: startStakingView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
