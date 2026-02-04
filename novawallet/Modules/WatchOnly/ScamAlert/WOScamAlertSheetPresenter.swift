import Foundation
import Foundation_iOS

final class WOScamAlertSheetPresenter {
    weak var view: WOScamAlertSheetViewProtocol?

    let wireframe: WOScamAlertSheetWireframeProtocol
    let viewModelFactory: WOScamAlertSheetViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let countdownDuration: Int

    private var timer: Timer?
    private var remainingSeconds: Int

    init(
        wireframe: WOScamAlertSheetWireframeProtocol,
        viewModelFactory: WOScamAlertSheetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        countdownDuration: Int = 8
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.countdownDuration = countdownDuration
        remainingSeconds = countdownDuration
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Private

private extension WOScamAlertSheetPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(for: localizationManager.selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }

    func startTimer() {
        remainingSeconds = countdownDuration
        view?.didStartTimer(totalSeconds: countdownDuration)

        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.timerTick()
        }
    }

    func timerTick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            invalidateTimer()
            view?.didFinishTimer()
        } else {
            view?.didUpdateTimer(remainingSeconds: remainingSeconds)
        }
    }

    func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - WOScamAlertSheetPresenterProtocol

extension WOScamAlertSheetPresenter: WOScamAlertSheetPresenterProtocol {
    func openSupportEmail() {
        wireframe.openEmail()
    }

    func setup() {
        provideViewModel()
        startTimer()
    }

    func cancel() {
        invalidateTimer()
        wireframe.complete(from: view, confirmed: false)
    }

    func confirm() {
        wireframe.complete(from: view, confirmed: true)
    }
}
