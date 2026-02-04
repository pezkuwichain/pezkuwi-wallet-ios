import Foundation
import Foundation_iOS
import Keystore_iOS

struct ASMInfoPopupViewFactory {
    static func createView(info: ASMRemoteData) -> InfoPopupViewProtocol? {
        let localizationManager = LocalizationManager.shared

        // Create AppMigrationRemoteConfig from ASMRemoteData
        let migrationConfig = AppMigrationRemoteConfig(
            destinationAppLinkURL: info.destinationLinkData.universalLink,
            destinationScheme: info.destinationLinkData.urlScheme,
            originScheme: info.sourceLinkData.urlScheme
        )

        // Create AppMigrationOrigin to start the migration flow
        let appMigrationOrigin = AppMigrationFactory.createOrigin(config: migrationConfig)

        let interactor = ASMInfoPopupInteractor(
            settingsManager: SettingsManager.shared,
            appMigrationOrigin: appMigrationOrigin,
            migrationConfig: migrationConfig
        )

        let wireframe = InfoPopupWireframe()
        let viewModelFactory = ASMInfoPopupViewModelFactory()

        let presenter = ASMInfoPopupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            learnMoreURL: info.wikiURL,
            mainAction: .custom {},
            skipAction: .custom {},
            localizationManager: localizationManager
        )

        guard let bannersModule = BannersViewFactory.createView(
            domain: .appStoreMigration,
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
