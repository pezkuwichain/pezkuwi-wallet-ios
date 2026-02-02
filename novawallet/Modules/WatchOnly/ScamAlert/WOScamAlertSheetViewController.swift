import UIKit
import Foundation_iOS
import UIKit_iOS

final class WOScamAlertSheetViewController: UIViewController, ViewHolder {
    typealias RootViewType = WOScamAlertSheetViewLayout

    let presenter: WOScamAlertSheetPresenterProtocol

    private var confirmTitle: String = ""

    init(
        presenter: WOScamAlertSheetPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: 422.0)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WOScamAlertSheetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        presenter.setup()
    }
}

// MARK: - Private

private extension WOScamAlertSheetViewController {
    func setupHandlers() {
        rootView.cancelButton.addTarget(
            self,
            action: #selector(actionCancel),
            for: .touchUpInside
        )
        rootView.timerButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
        rootView.onSupportTapped = { [weak self] in
            self?.presenter.openSupportEmail()
        }
    }

    @objc func actionCancel() {
        presenter.cancel()
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }
}

// MARK: - WOScamAlertSheetViewProtocol

extension WOScamAlertSheetViewController: WOScamAlertSheetViewProtocol {
    func didReceive(viewModel: WOScamAlertSheetViewModel) {
        rootView.titleLabel.text = viewModel.title
        rootView.messageLabel.attributedText = viewModel.message
        rootView.contactLabel.attributedText = viewModel.contact
        rootView.cancelButton.imageWithTitleView?.title = viewModel.cancelTitle
        confirmTitle = viewModel.confirmTitle
    }

    func didStartTimer(totalSeconds: Int) {
        rootView.timerButton.startTimer(totalSeconds: totalSeconds)
    }

    func didUpdateTimer(remainingSeconds: Int) {
        rootView.timerButton.updateTimerLabel(remainingSeconds: remainingSeconds)
    }

    func didFinishTimer() {
        rootView.timerButton.finishTimer(title: confirmTitle)
    }
}

// MARK: - Localizable

extension WOScamAlertSheetViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }
        presenter.setup()
    }
}

// MARK: - ModalPresenterDelegate

extension WOScamAlertSheetViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }

    func presenterDidHide(_: ModalPresenterProtocol) {}
}
