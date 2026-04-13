import UIKit

/// Routing for the new Subtensor stake setup flow.
///
/// `showValidatorPicker` builds a `SubtensorValidatorPickerViewController`
/// and presents it inside a `UINavigationController` so the picker has
/// access to its own large-title nav bar without disrupting the underlying
/// stack. The picker dismisses itself once a validator is tapped.
///
/// `showStubConfirm` is a Phase A placeholder — Phase B will replace it
/// with a real confirm screen / extrinsic submission flow.
final class SubtensorStakeSetupWireframe: SubtensorStakeSetupWireframeProtocol {
    func showValidatorPicker(
        from view: SubtensorStakeSetupViewProtocol?,
        netuid: UInt16,
        prefetched: [SubtensorValidator],
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        onSelected: @escaping (SubtensorValidator) -> Void
    ) {
        let picker = SubtensorValidatorPickerViewController(
            netuid: netuid,
            validatorProvider: validatorProvider,
            cellViewModelFactory: cellViewModelFactory,
            prefetched: prefetched,
            onSelection: onSelected
        )

        let navController = UINavigationController(rootViewController: picker)
        navController.navigationBar.prefersLargeTitles = true
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        // Add a Cancel button so the user can dismiss without selection.
        // TODO(phase-e): R.string.localizable.commonCancel(...)
        picker.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: picker,
            action: #selector(SubtensorValidatorPickerViewController.dismissAnimated)
        )

        view?.controller.present(navController, animated: true)
    }

    func showError(from view: SubtensorStakeSetupViewProtocol?, message: String) {
        // TODO(phase-e): R.string.localizable.commonErrorGeneralTitle(...)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view?.controller.present(alert, animated: true)
    }

    func showConfirm(
        from view: SubtensorStakeSetupViewProtocol?,
        chainAsset: ChainAsset,
        validator: SubtensorValidator,
        amount: Decimal
    ) {
        guard let confirmView = SubtensorStakeConfirmViewFactory.createView(
            chainAsset: chainAsset,
            validator: validator,
            amount: amount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}

// MARK: - Cancel button hook

extension SubtensorValidatorPickerViewController {
    @objc func dismissAnimated() {
        dismiss(animated: true)
    }
}
