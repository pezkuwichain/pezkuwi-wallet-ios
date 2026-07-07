import Foundation
import UIKit
import UIKit_iOS

/// Mirrors `Modules/Banners/View/BannersContainerCollectionViewCell.swift` — a thin container cell
/// that embeds the self-contained `PezkuwiDashboard` module's root view as a child view controller.
final class PezkuwiDashboardContainerCollectionViewCell: CollectionViewContainerCell<UIView> {
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            view.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }
}
