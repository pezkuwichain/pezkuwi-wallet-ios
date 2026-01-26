import UIKit

struct InfoPopupViewModel {
    let bannerState: BannersState
    let title: String
    let subtitle: String?
    let features: [Feature]
    let infoItems: [InfoItem]
    let additionalInfo: String?
    let mainActionTitle: String
    let skipActionTitle: String?
    let learnMoreTitle: String?

    struct Feature {
        let emoji: String
        let text: String
    }

    struct InfoItem {
        let icon: Icon
        let text: String

        enum Icon {
            case history
            case migration
            case custom(UIImage?)
        }
    }

    static func empty(with bannerState: BannersState) -> InfoPopupViewModel {
        InfoPopupViewModel(
            bannerState: bannerState,
            title: "",
            subtitle: nil,
            features: [],
            infoItems: [],
            additionalInfo: nil,
            mainActionTitle: "",
            skipActionTitle: nil,
            learnMoreTitle: nil
        )
    }
}
