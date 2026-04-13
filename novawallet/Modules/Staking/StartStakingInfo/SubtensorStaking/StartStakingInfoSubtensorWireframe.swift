import Foundation
import UIKit
import Foundation_iOS

/// Routes the "Start staking" button on Nova's generic info screen to the
/// TAO staking dashboard. From the dashboard the user can see existing
/// positions and start new stakes (Root or Subnet).
final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe {
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        // Resolve the current wallet's coldkey for this chain.
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let accountResponse = wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        else {
            return
        }

        let coldkey = accountResponse.chainAccount.accountId

        let dashboard = SubtensorStakingViewFactory.createView(
            chainAsset: chainAsset,
            coldkey: coldkey
        )

        view?.controller.navigationController?.pushViewController(dashboard, animated: true)
    }
}
