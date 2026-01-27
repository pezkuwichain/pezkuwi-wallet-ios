import Foundation
import Foundation_iOS

class InfoPopupPresenter: BannersModuleInputOwnerProtocol {
    weak var view: InfoPopupViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    let wireframe: InfoPopupWireframeProtocol
    let interactor: InfoPopupInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    var mainAction: InfoPopupAction?
    var skipAction: InfoPopupAction?
    var learnMoreURL: URL?

    init(
        interactor: InfoPopupInteractorInputProtocol,
        wireframe: InfoPopupWireframeProtocol,
        mainAction: InfoPopupAction?,
        skipAction: InfoPopupAction?,
        learnMoreURL: URL?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.mainAction = mainAction
        self.skipAction = skipAction
        self.learnMoreURL = learnMoreURL
        self.localizationManager = localizationManager
    }

    func createViewModel(
        bannerState _: BannersState,
        locale _: Locale
    ) -> InfoPopupViewModel? {
        fatalError("Subclasses must override createViewModel")
    }

    func provideViewModel() {
        guard let viewModel = createViewModel(
            bannerState: bannersModule?.bannersState ?? .unavailable,
            locale: localizationManager.selectedLocale
        ) else {
            return
        }

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - InfoPopupPresenterProtocol

extension InfoPopupPresenter: InfoPopupPresenterProtocol {
    func setup() {
        interactor.setup()

        guard bannersModule?.locale != localizationManager.selectedLocale else { return }

        bannersModule?.updateLocale(localizationManager.selectedLocale)
    }

    func actionMain() {
        interactor.performMainAction()
    }

    func actionSkip() {
        interactor.performSkipAction()
    }

    func actionLearnMore() {
        guard let view, let learnMoreURL else { return }

        wireframe.showWeb(
            url: learnMoreURL,
            from: view,
            style: .automatic
        )
    }
}

// MARK: - InfoPopupInteractorOutputProtocol

extension InfoPopupPresenter: InfoPopupInteractorOutputProtocol {
    func didSetup() {
        provideViewModel()
    }

    func didCompleteMainAction() {
        wireframe.proceed(from: view, action: mainAction)
    }

    func didCompleteSkipAction() {
        wireframe.proceed(from: view, action: skipAction)
    }

    func didReceive(error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: - BannersModuleOutputProtocol

extension InfoPopupPresenter: BannersModuleOutputProtocol {
    func didReceiveBanners(state _: BannersState) {
        provideViewModel()
    }

    func didUpdateContent(state _: BannersState) {
        provideViewModel()
    }

    func didReceive(_ error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: - Localizable

extension InfoPopupPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel()
        bannersModule?.updateLocale(localizationManager.selectedLocale)
    }
}
