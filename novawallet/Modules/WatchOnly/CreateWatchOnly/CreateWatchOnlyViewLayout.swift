import UIKit
import Foundation_iOS
import UIKit_iOS

final class CreateWatchOnlyViewLayout: SCSingleActionLayoutView {
    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
    }

    let detailsLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextSecondary()
        view.font = .regularFootnote
        view.numberOfLines = 0
    }

    let presetSegmentControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
        view.backgroundView.cornerRadius = Constants.segmentControlCornerRadius
    }

    let walletNameTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let walletNameInputView = TextInputView()

    let substrateAddressTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let substrateAddressInputView: AccountInputView = .create { view in
        view.showsMyself = false
        view.localizablePlaceholder = .init(closure: { _ in Constants.substrateFieldPlaceholder })
    }

    let evmAddressTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let evmAddressInputView: AccountInputView = .create { view in
        view.showsMyself = false
        view.localizablePlaceholder = .init(closure: { _ in Constants.evmFieldPlaceholder })
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: Constants.fieldTitleOffset)
        addArrangedSubview(detailsLabel, spacingAfter: Constants.fieldOffset)

        addArrangedSubview(presetSegmentControl, spacingAfter: Constants.fieldOffset)

        addArrangedSubview(walletNameTitleLabel, spacingAfter: Constants.fieldTitleOffset)
        addArrangedSubview(walletNameInputView, spacingAfter: Constants.fieldOffset)

        addArrangedSubview(substrateAddressTitleLabel, spacingAfter: Constants.fieldTitleOffset)
        addArrangedSubview(substrateAddressInputView, spacingAfter: Constants.fieldOffset)

        addArrangedSubview(evmAddressTitleLabel, spacingAfter: Constants.fieldTitleOffset)
        addArrangedSubview(evmAddressInputView, spacingAfter: Constants.fieldOffset)

        presetSegmentControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.segmentControlHeight)
        }
    }

    override func setupStyle() {
        super.setupStyle()
        
        backgroundColor = R.color.colorSecondaryScreenBackground()
        genericActionView.applyDefaultStyle()
    }
}

// MARK: - Constants

private extension CreateWatchOnlyViewLayout {
    enum Constants {
        static let segmentControlHeight: CGFloat = 40
        static let fieldTitleOffset: CGFloat = 8.0
        static let fieldOffset: CGFloat = 16.0
        static let segmentControlCornerRadius: CGFloat = 12.0
        static let substrateFieldPlaceholder = "1..."
        static let evmFieldPlaceholder = "0x..."
    }
}

// MARK: - Label Factories

extension CreateWatchOnlyViewLayout {
    static func createSectionTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }

    static func createHintLabel() -> UILabel {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }
}
