import Foundation

class InfoPopupInteractor {
    weak var presenter: InfoPopupInteractorOutputProtocol?

    func setup() {
        presenter?.didSetup()
    }

    func performMainAction() {
        presenter?.didCompleteMainAction()
    }

    func performSkipAction() {
        presenter?.didCompleteSkipAction()
    }
}

// MARK: - InfoPopupInteractorInputProtocol

extension InfoPopupInteractor: InfoPopupInteractorInputProtocol {}
