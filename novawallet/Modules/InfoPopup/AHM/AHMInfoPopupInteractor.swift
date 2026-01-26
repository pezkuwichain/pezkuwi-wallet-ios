import Foundation
import Keystore_iOS

final class AHMInfoPopupInteractor: InfoPopupInteractor {
    weak var ahmPresenter: AHMInfoPopupInteractorOutputProtocol?

    private let info: AHMRemoteData
    private let chainRegistry: ChainRegistryProtocol
    private let settingsManager: SettingsManagerProtocol

    init(
        info: AHMRemoteData,
        chainRegistry: ChainRegistryProtocol,
        settingsManager: SettingsManagerProtocol
    ) {
        self.info = info
        self.chainRegistry = chainRegistry
        self.settingsManager = settingsManager
    }

    override func setup() {
        let sourceChain = chainRegistry.getChain(for: info.sourceData.chainId)
        let destinationChain = chainRegistry.getChain(for: info.destinationData.chainId)

        ahmPresenter?.didReceive(
            info: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain
        )
    }

    override func performMainAction() {
        settingsManager.ahmInfoShownChains.add(info.sourceData.chainId)
        presenter?.didCompleteMainAction()
    }
}
