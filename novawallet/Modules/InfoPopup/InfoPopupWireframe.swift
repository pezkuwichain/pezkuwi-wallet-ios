import UIKit

final class InfoPopupWireframe: InfoPopupWireframeProtocol {
    func complete(from view: InfoPopupViewProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)
    }

    func proceed(from view: InfoPopupViewProtocol?, action: InfoPopupAction?) {
        guard let action else {
            complete(from: view)
            return
        }

        switch action {
        case let .url(url):
            complete(from: view)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)

        case let .deepLink(deepLink):
            complete(from: view)
            if let url = URL(string: deepLink) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

        case let .custom(closure):
            complete(from: view)
            closure()
        }
    }
}
