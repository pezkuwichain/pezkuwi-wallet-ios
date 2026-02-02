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

    let termsView: RowView<IconDetailsView> = .create { view in
        view.rowContentView.iconWidth = Constants.termsCheckboxIconWidth
        view.rowContentView.spacing = Constants.termsContentSpacing
        view.rowContentView.stackView.alignment = .top
        view.roundedBackgroundView.apply(style: .roundedLightCell)

        view.rowContentView.imageView.image = R.image.iconCheckboxEmpty()
        view.rowContentView.detailsLabel.numberOfLines = 0

        view.contentInsets = Constants.temsContainerInsets
    }

    override func setupLayout() {
        super.setupLayout()

        layoutTermsView()

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

// MARK: - Private

private extension CreateWatchOnlyViewLayout {
    func layoutTermsView() {
        addSubview(termsView)

        termsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(genericActionView.snp.top).inset(-UIConstants.actionBottomInset)
        }

        containerView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(termsView.snp.top).offset(-Constants.fieldOffset)
        }
    }
}

// MARK: - Constants

private extension CreateWatchOnlyViewLayout {
    enum Constants {
        static let segmentControlHeight: CGFloat = 40
        static let fieldTitleOffset: CGFloat = 8.0
        static let fieldOffset: CGFloat = 16.0
        static let segmentControlCornerRadius: CGFloat = 12.0
        static let termsCheckboxIconWidth: CGFloat = 24.0
        static let termsContentSpacing: CGFloat = 14.0
        static let temsContainerInsets: UIEdgeInsets = .init(inset: 12)
        static let substrateFieldPlaceholder = "1..."
        static let evmFieldPlaceholder = "0x..."
    }
}

// MARK: - Label Factories

extension CreateWatchOnlyViewLayout {
    static func createSectionTitleLabel() -> UILabel {
        .create { view in
            view.font = .regularFootnote
            view.textColor = R.color.colorTextSecondary()
        }
    }
}
