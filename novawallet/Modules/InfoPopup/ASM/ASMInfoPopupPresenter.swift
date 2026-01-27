import Foundation
import Foundation_iOS

final class ASMInfoPopupPresenter: InfoPopupPresenter {
    private let viewModelFactory: ASMInfoPopupViewModelFactoryProtocol

    init(
        interactor: InfoPopupInteractorInputProtocol,
        wireframe: InfoPopupWireframeProtocol,
        viewModelFactory: ASMInfoPopupViewModelFactoryProtocol,
        learnMoreURL: URL?,
        mainAction: InfoPopupAction?,
        skipAction: InfoPopupAction?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewModelFactory = viewModelFactory

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            mainAction: mainAction,
            skipAction: skipAction,
            learnMoreURL: learnMoreURL,
            localizationManager: localizationManager
        )
    }

    override func createViewModel(
        bannerState: BannersState,
        locale: Locale
    ) -> InfoPopupViewModel? {
        viewModelFactory.createViewModel(
            bannerState: bannerState,
            locale: locale
        )
    }
}
