import UIKit

struct InfoPopupViewModel {
    let bannerState: BannersState
    let title: String
    let subtitle: String?
    let features: [Feature]
    let additionalInfo: String?
    let mainActionTitle: String
    let skipActionTitle: String?
    let learnMoreTitle: String?

    struct Feature {
        let emoji: String
        let text: String
    }
}
