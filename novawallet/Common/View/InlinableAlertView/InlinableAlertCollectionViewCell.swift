import Foundation
import UIKit

final class InlinableAlertCollectionViewCell: CollectionViewContainerCell<InlinableAlertView> {
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            view.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    func bind(_ viewModel: InlinableAlertView.Model) {
        view.bind(viewModel)
    }
}
