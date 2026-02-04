import Foundation
import UIKit

extension InlinableAlertView {
    struct Model {
        let type: AlertType
        let title: String
        let message: String?
        let learnMore: LearnMoreViewModel
        let actionTitle: String?
        let icon: UIImage?
        let showCloseButton: Bool
    }
}

extension InlinableAlertView.Model {
    enum AlertType {
        case ahmAssetDetails
        case ahmStakingDetails
        case watchOnlyAssetList
    }
}
