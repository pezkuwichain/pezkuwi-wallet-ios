import Foundation

final class WOScamAlertSheetWireframe: WOScamAlertSheetWireframeProtocol {
    weak var delegate: WOScamAlertSheetDelegate?

    func complete(from view: WOScamAlertSheetViewProtocol?, confirmed: Bool) {
        view?.controller.dismiss(animated: true) { [weak self] in
            if confirmed {
                self?.delegate?.woScamAlertSheetDidConfirm()
            } else {
                self?.delegate?.woScamAlertSheetDidCancel()
            }
        }
    }
}
