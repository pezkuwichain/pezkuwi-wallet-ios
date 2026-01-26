import Foundation
import Foundation_iOS

final class AHMInfoPopupPresenter: BannersModuleInputOwnerProtocol {
    weak var view: InfoPopupViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    private let wireframe: InfoPopupWireframeProtocol
    private let interactor: InfoPopupInteractorInputProtocol
    private let viewModelFactory: AHMInfoPopupViewModelFactoryProtocol
    private let localizationManager: LocalizationManagerProtocol

    private var info: AHMRemoteData?
    private var sourceChain: ChainModel?
    private var destinationChain: ChainModel?

    init(
        interactor: InfoPopupInteractorInputProtocol,
        wireframe: InfoPopupWireframeProtocol,
        viewModelFactory: AHMInfoPopupViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        guard
            let info,
            let sourceChain,
            let destinationChain
        else { return }

        let content = viewModelFactory.createContent(
            from: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            locale: localizationManager.selectedLocale
        )

        let viewModel = InfoPopupViewModel(
            bannerState: bannersModule?.bannersState ?? .unavailable,
            title: content.title,
            subtitle: content.subtitle,
            features: content.features.map {
                InfoPopupViewModel.Feature(emoji: $0.emoji, text: $0.text)
            },
            infoItems: content.infoItems.map {
                InfoPopupViewModel.InfoItem(icon: $0.icon, text: $0.text)
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

extension AHMInfoPopupPresenter: InfoPopupPresenterProtocol {
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
        guard let view, let info else { return }

        wireframe.showWeb(
            url: info.wikiURL,
            from: view,
            style: .automatic
        )
    }
}

// MARK: - AHMInfoPopupInteractorOutputProtocol

extension AHMInfoPopupPresenter: AHMInfoPopupInteractorOutputProtocol {
    func didReceive(
        info: AHMRemoteData,
        sourceChain: ChainModel?,
        destinationChain: ChainModel?
    ) {
        self.info = info
        self.sourceChain = sourceChain
        self.destinationChain = destinationChain

        provideViewModel()
    }

    func didCompleteMainAction() {
        wireframe.complete(from: view)
    }

    func didCompleteSkipAction() {
        wireframe.complete(from: view)
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

extension AHMInfoPopupPresenter: BannersModuleOutputProtocol {
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

extension AHMInfoPopupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
            bannersModule?.updateLocale(localizationManager.selectedLocale)
        }
    }
}
