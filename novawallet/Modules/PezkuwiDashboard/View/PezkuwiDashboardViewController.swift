import UIKit

final class PezkuwiDashboardViewController: UIViewController {
    var rootCardView: PezkuwiDashboardCardView {
        // swiftlint:disable:next force_cast
        view as! PezkuwiDashboardCardView
    }

    let presenter: PezkuwiDashboardPresenterProtocol

    init(presenter: PezkuwiDashboardPresenterProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let cardView = PezkuwiDashboardCardView()
        cardView.delegate = self
        view = cardView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

// MARK: - PezkuwiDashboardViewProtocol

extension PezkuwiDashboardViewController: PezkuwiDashboardViewProtocol {
    func didReceive(viewModel: PezkuwiDashboardViewModel?) {
        guard let viewModel else { return }

        rootCardView.bind(viewModel: viewModel)
    }

    func didReceive(trackingLoading: Bool) {
        rootCardView.bind(trackingLoading: trackingLoading)
    }
}

// MARK: - PezkuwiDashboardViewProviderProtocol

extension PezkuwiDashboardViewController: PezkuwiDashboardViewProviderProtocol {
    func getCardHeight() -> CGFloat {
        rootCardView.currentHeight
    }
}

// MARK: - PezkuwiDashboardCardViewDelegate

extension PezkuwiDashboardViewController: PezkuwiDashboardCardViewDelegate {
    func pezkuwiDashboardCardDidToggleExpanded(_: PezkuwiDashboardCardView) {
        presenter.toggleExpanded()
    }

    func pezkuwiDashboardCardDidTapApply(_: PezkuwiDashboardCardView) {
        presenter.applyClicked()
    }

    func pezkuwiDashboardCardDidTapSign(_: PezkuwiDashboardCardView) {
        presenter.signClicked()
    }

    func pezkuwiDashboardCardDidTapShare(_: PezkuwiDashboardCardView) {
        presenter.shareReferralClicked()
    }

    func pezkuwiDashboardCardDidTapStartTracking(_: PezkuwiDashboardCardView) {
        presenter.startTrackingClicked()
    }
}
