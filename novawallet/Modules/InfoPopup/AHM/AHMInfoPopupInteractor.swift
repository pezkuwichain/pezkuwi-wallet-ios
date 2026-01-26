import Foundation
import Keystore_iOS

final class AHMInfoPopupInteractor {
    weak var presenter: AHMInfoPopupInteractorOutputProtocol?

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
}

// MARK: - InfoPopupInteractorInputProtocol

extension AHMInfoPopupInteractor: InfoPopupInteractorInputProtocol {
    func setup() {
        let sourceChain = chainRegistry.getChain(for: info.sourceData.chainId)
        let destinationChain = chainRegistry.getChain(for: info.destinationData.chainId)

        presenter?.didReceive(
            info: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain
        )
    }

    func performMainAction() {
        settingsManager.ahmInfoShownChains.add(info.sourceData.chainId)
        presenter?.didCompleteMainAction()
    }

    func performSkipAction() {
        presenter?.didCompleteSkipAction()
    }
}
