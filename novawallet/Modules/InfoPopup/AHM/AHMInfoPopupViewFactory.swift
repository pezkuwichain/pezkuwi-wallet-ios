import Foundation
import Foundation_iOS
import Keystore_iOS

struct AHMInfoPopupViewFactory {
    static func createView(
        info: AHMRemoteData
    ) -> InfoPopupViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let localizationManager = LocalizationManager.shared

        let interactor = AHMInfoPopupInteractor(
            info: info,
            chainRegistry: chainRegistry,
            settingsManager: SettingsManager.shared
        )

        let wireframe = InfoPopupWireframe()
        let viewModelFactory = AHMInfoPopupViewModelFactory()

        let presenter = AHMInfoPopupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        guard let bannersModule = BannersViewFactory.createView(
            domain: info.bannerPath,
            output: presenter,
            inputOwner: presenter,
            locale: localizationManager.selectedLocale
        ) else {
            return nil
        }

        let view = InfoPopupViewController(
            presenter: presenter,
            bannersViewProvider: bannersModule,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
