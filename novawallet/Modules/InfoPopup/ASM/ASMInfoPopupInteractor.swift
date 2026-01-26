import Foundation
import Keystore_iOS

final class ASMInfoPopupInteractor: InfoPopupInteractor {
    private let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }

    override func performMainAction() {
        settingsManager.appStoreMigrationShown = true
        presenter?.didCompleteMainAction()
    }

    override func performSkipAction() {
        settingsManager.appStoreMigrationShown = true
        presenter?.didCompleteSkipAction()
    }
}
