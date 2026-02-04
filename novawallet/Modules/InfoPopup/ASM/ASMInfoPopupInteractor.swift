import Foundation
import Keystore_iOS

final class ASMInfoPopupInteractor: InfoPopupInteractor {
    private let settingsManager: SettingsManagerProtocol
    private let appMigrationOrigin: AppMigrationOriginProtocol
    private let migrationConfig: AppMigrationRemoteConfig

    init(
        settingsManager: SettingsManagerProtocol,
        appMigrationOrigin: AppMigrationOriginProtocol,
        migrationConfig: AppMigrationRemoteConfig
    ) {
        self.settingsManager = settingsManager
        self.appMigrationOrigin = appMigrationOrigin
        self.migrationConfig = migrationConfig
    }

    override func performMainAction() {
        settingsManager.appStoreMigrationShown = true

        do {
            // Start migration by opening the destination app
            // The origin app's scheme is used for the destination to respond back
            let originScheme = migrationConfig.originScheme
            let startMessage = AppMigrationMessage.Start(originScheme: originScheme)

            try appMigrationOrigin.start(with: startMessage)

            presenter?.didCompleteMainAction()
        } catch {
            presenter?.didReceive(error: error)
        }
    }

    override func performSkipAction() {
        settingsManager.appStoreMigrationShown = true
        presenter?.didCompleteSkipAction()
    }
}
