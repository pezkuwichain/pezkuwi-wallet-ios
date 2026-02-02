import Foundation
import UIKit

final class WOScamAlertSheetWireframe: WOScamAlertSheetWireframeProtocol {
    private let supportEmail: String
    weak var delegate: WOScamAlertSheetDelegate?

    init(supportEmail: String) {
        self.supportEmail = supportEmail
    }

    func complete(from view: WOScamAlertSheetViewProtocol?, confirmed: Bool) {
        view?.controller.dismiss(animated: true) { [weak self] in
            if confirmed {
                self?.delegate?.woScamAlertSheetDidConfirm()
            } else {
                self?.delegate?.woScamAlertSheetDidCancel()
            }
        }
    }

    func openEmail() {
        guard let url = URL(string: "mailto:\(supportEmail)") else { return }

        UIApplication.shared.open(url)
    }
}
