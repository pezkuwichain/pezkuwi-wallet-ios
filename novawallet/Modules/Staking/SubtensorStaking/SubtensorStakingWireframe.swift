import UIKit

final class SubtensorStakingWireframe: SubtensorStakingWireframeProtocol {
    func showError(from view: UIViewController, message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view.present(alert, animated: true)
    }
}
