import Foundation
import Foundation_iOS

final class AHMInfoPopupPresenter: InfoPopupPresenter {
    private let viewModelFactory: AHMInfoPopupViewModelFactoryProtocol

    private var info: AHMRemoteData?
    private var sourceChain: ChainModel?
    private var destinationChain: ChainModel?

    init(
        interactor: AHMInfoPopupInteractor,
        wireframe: InfoPopupWireframeProtocol,
        viewModelFactory: AHMInfoPopupViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewModelFactory = viewModelFactory

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            mainAction: nil,
            skipAction: nil,
            learnMoreURL: nil,
            localizationManager: localizationManager
        )

        interactor.ahmPresenter = self
    }

    override func createViewModel(
        bannerState: BannersState,
        locale: Locale
    ) -> InfoPopupViewModel? {
        guard
            let info,
            let sourceChain,
            let destinationChain
        else {
            return nil
        }

        return viewModelFactory.createViewModel(
            from: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            bannerState: bannerState,
            locale: locale
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
}
