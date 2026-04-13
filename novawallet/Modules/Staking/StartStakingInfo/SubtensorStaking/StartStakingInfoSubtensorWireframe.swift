import Foundation
import UIKit
import Foundation_iOS

/// Routes the "Start staking" button on Nova's generic info screen to
/// the Subtensor staking type selection (Root vs Subnet), then to the
/// appropriate setup flow.
final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe {
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        let localizationManager = LocalizationManager.shared

        let typeViewController = SubtensorStakingTypeViewController(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        ) { [weak self] selection in
            guard let self else { return }

            switch selection {
            case .root:
                self.showRootSetup(from: view)
            case .subnet:
                self.showSubnetPicker(from: view)
            }
        }

        view?.controller.navigationController?.pushViewController(
            typeViewController,
            animated: true
        )
    }

    private func showRootSetup(from view: ControllerBackedProtocol?) {
        guard let setupView = SubtensorStakeSetupViewFactory.createView(
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView,
            animated: true
        )
    }

    private func showSubnetPicker(from view: ControllerBackedProtocol?) {
        let localizationManager = LocalizationManager.shared

        let pickerVC = SubtensorSubnetPickerViewController(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        ) { [weak self] subnet in
            guard let self else { return }
            self.showSubnetSetup(from: view, netuid: subnet.netuid, subnetName: subnet.name)
        }

        view?.controller.navigationController?.pushViewController(
            pickerVC,
            animated: true
        )
    }

    private func showSubnetSetup(from view: ControllerBackedProtocol?, netuid: UInt16, subnetName: String?) {
        guard let setupView = SubtensorStakeSetupViewFactory.createView(
            chainAsset: chainAsset,
            netuid: netuid,
            subnetName: subnetName
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView,
            animated: true
        )
    }
}
