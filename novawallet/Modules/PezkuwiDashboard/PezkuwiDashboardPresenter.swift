import Foundation
import Foundation_iOS

final class PezkuwiDashboardPresenter {
    weak var view: PezkuwiDashboardViewProtocol?
    weak var moduleOutput: PezkuwiDashboardModuleOutputProtocol?

    let interactor: PezkuwiDashboardInteractorInputProtocol
    let wireframe: PezkuwiDashboardWireframeProtocol

    /// Resets to `false` on every fresh construction of this module (app relaunch / screen
    /// reconstruction) — never persisted — matching Android's `PezkuwiDashboardAdapter.isExpanded`
    /// comment: "resets to collapsed (false) whenever the app is freshly opened, by design."
    private(set) var isExpanded: Bool = false

    private(set) var trackingLoading: Bool = false

    private var dashboard: PezkuwiDashboardData?

    init(
        interactor: PezkuwiDashboardInteractorInputProtocol,
        wireframe: PezkuwiDashboardWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe

        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension PezkuwiDashboardPresenter {
    func provideViewModel() {
        guard let dashboard else {
            view?.didReceive(viewModel: nil)
            return
        }

        let welatiFormatter = NumberFormatter()
        welatiFormatter.numberStyle = .decimal
        welatiFormatter.locale = selectedLocale

        let welatiCount = welatiFormatter.string(from: NSNumber(value: dashboard.welatiCount))
            ?? String(dashboard.welatiCount)

        let viewModel = PezkuwiDashboardViewModel(
            roles: dashboard.roles,
            trustScore: String(dashboard.trustScore),
            welatiCount: welatiCount,
            citizenshipStatus: dashboard.citizenshipStatus,
            isTrackingScore: dashboard.isTrackingScore
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - PezkuwiDashboardPresenterProtocol

extension PezkuwiDashboardPresenter: PezkuwiDashboardPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func refresh() {
        interactor.refresh()
    }

    func toggleExpanded() {
        isExpanded.toggle()

        moduleOutput?.didChangePezkuwiDashboardHeight()
    }

    func applyClicked() {
        wireframe.showCitizenshipApplication(from: view)
    }

    func signClicked() {
        wireframe.showCitizenshipApplication(from: view)
    }

    func shareReferralClicked() {
        interactor.requestReferralAddress()
    }

    func startTrackingClicked() {
        guard !trackingLoading else { return }

        trackingLoading = true
        view?.didReceive(trackingLoading: true)

        interactor.startTracking()
    }
}

// MARK: - PezkuwiDashboardInteractorOutputProtocol

extension PezkuwiDashboardPresenter: PezkuwiDashboardInteractorOutputProtocol {
    func didReceive(dashboard: PezkuwiDashboardData?) {
        let wasAvailable = self.dashboard != nil
        self.dashboard = dashboard

        provideViewModel()

        let isAvailable = dashboard != nil

        if wasAvailable != isAvailable {
            moduleOutput?.didReceivePezkuwiDashboard(available: isAvailable)
        }

        moduleOutput?.didChangePezkuwiDashboardHeight()
    }

    func didStartTracking() {
        trackingLoading = false
        view?.didReceive(trackingLoading: false)
    }

    func didReceiveTracking(error: Error) {
        trackingLoading = false
        view?.didReceive(trackingLoading: false)

        wireframe.present(
            message: error.localizedDescription,
            title: "Score tracking failed",
            closeAction: "Close",
            from: view
        )
    }

    func didReceive(referralAddress: AccountAddress) {
        let telegramLink = "https://t.me/pezkuwichainBot?start=\(referralAddress)"
        let shareText =
            "Dear friend, Digital Kurdistan has been established, take your place!\n\n" +
            "\(telegramLink)\n\n" +
            "Paste this address in the referral field:\n\(referralAddress)"

        wireframe.share(items: [shareText], from: view, with: nil)
    }
}

// MARK: - PezkuwiDashboardModuleInputProtocol

extension PezkuwiDashboardPresenter: PezkuwiDashboardModuleInputProtocol {
    var isAvailable: Bool { dashboard != nil }
}

// MARK: - Localizable

extension PezkuwiDashboardPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
