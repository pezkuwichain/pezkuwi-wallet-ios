import Foundation
import Foundation_iOS

class InfoPopupInteractor {
    weak var presenter: InfoPopupInteractorOutputProtocol?

    private let localizedContent: InfoPopupLocalizedContent
    private let localizationManager: LocalizationManagerProtocol

    init(
        localizedContent: InfoPopupLocalizedContent,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizedContent = localizedContent
        self.localizationManager = localizationManager
    }
}

// MARK: - InfoPopupInteractorInputProtocol

extension InfoPopupInteractor: InfoPopupInteractorInputProtocol {
    func setup() {
        let content = InfoPopupContent.from(
            localized: localizedContent,
            locale: localizationManager.selectedLocale
        )
        presenter?.didReceive(content: content)
    }

    func performMainAction() {
        presenter?.didCompleteMainAction()
    }

    func performSkipAction() {
        presenter?.didCompleteSkipAction()
    }
}
