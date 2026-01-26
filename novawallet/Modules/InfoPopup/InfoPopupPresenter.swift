import Foundation
import Foundation_iOS

final class InfoPopupPresenter: BannersModuleInputOwnerProtocol {
    weak var view: InfoPopupViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    private let wireframe: InfoPopupWireframeProtocol
    private let interactor: InfoPopupInteractorInputProtocol
    private let localizationManager: LocalizationManagerProtocol

    private var content: InfoPopupContent?
    private var mainAction: InfoPopupAction?
    private var skipAction: InfoPopupAction?

    init(
        interactor: InfoPopupInteractorInputProtocol,
        wireframe: InfoPopupWireframeProtocol,
        mainAction: InfoPopupAction?,
        skipAction: InfoPopupAction?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.mainAction = mainAction
        self.skipAction = skipAction
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        guard let content else { return }

        let viewModel = InfoPopupViewModel(
            bannerState: bannersModule?.bannersState ?? .unavailable,
            title: content.title,
            subtitle: content.subtitle,
            features: content.features.map {
                InfoPopupViewModel.Feature(emoji: $0.emoji, text: $0.text)
            },
            additionalInfo: content.additionalInfo,
            mainActionTitle: content.mainActionTitle,
            skipActionTitle: content.skipActionTitle,
            learnMoreTitle: content.learnMoreURL != nil
                ? R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages)
                .localizable.commonLearnMore()
                : nil
        )

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
        guard let view, let url = content?.learnMoreURL else { return }

        wireframe.showWeb(
            url: url,
            from: view,
            style: .automatic
        )
    }
}

// MARK: - InfoPopupInteractorOutputProtocol

extension InfoPopupPresenter: InfoPopupInteractorOutputProtocol {
    func didReceive(content: InfoPopupContent) {
        self.content = content
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
        if let view = view, view.isSetup {
            provideViewModel()
            bannersModule?.updateLocale(localizationManager.selectedLocale)
        }
    }
}
