import UIKit
import Foundation_iOS

final class SubtensorStakingWireframe: SubtensorStakingWireframeProtocol {
    private let chainAsset: ChainAsset
    private let localizationManager: LocalizationManagerProtocol

    init(chainAsset: ChainAsset, localizationManager: LocalizationManagerProtocol) {
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    // MARK: - SubtensorStakingWireframeProtocol

    /// Routes to the Root / Subnet type-selection screen, then to Setup → Confirm.
    func showStakingFlow(from view: UIViewController) {
        let typeVC = SubtensorStakingTypeViewController(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        ) { [weak self, weak view] selection in
            guard let self, let view else { return }
            switch selection {
            case .root:
                self.showRootSetup(from: view)
            case .subnet:
                self.showSubnetPicker(from: view)
            }
        }
        view.navigationController?.pushViewController(typeVC, animated: true)
    }

    func showUnstakeComingSoon(from view: UIViewController) {
        let alert = UIAlertController(
            title: "Coming soon",
            message: "Unstaking is not yet supported on iOS.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view.present(alert, animated: true)
    }

    func showError(from view: UIViewController, message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view.present(alert, animated: true)
    }

    // MARK: - Private routing helpers

    private func showRootSetup(from view: UIViewController) {
        guard let setupVC = SubtensorStakeSetupViewFactory.createView(chainAsset: chainAsset) else { return }
        view.navigationController?.pushViewController(setupVC, animated: true)
    }

    private func showSubnetPicker(from view: UIViewController) {
        let pickerVC = SubtensorSubnetPickerViewController(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        ) { [weak self, weak view] subnet in
            guard let self, let view else { return }
            self.showSubnetSetup(from: view, netuid: subnet.netuid, subnetName: subnet.name)
        }
        view.navigationController?.pushViewController(pickerVC, animated: true)
    }

    private func showSubnetSetup(from view: UIViewController, netuid: UInt16, subnetName: String?) {
        guard let setupVC = SubtensorStakeSetupViewFactory.createView(
            chainAsset: chainAsset,
            netuid: netuid,
            subnetName: subnetName
        ) else { return }
        view.navigationController?.pushViewController(setupVC, animated: true)
    }
}
