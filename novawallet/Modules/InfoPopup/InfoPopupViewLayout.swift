import UIKit
import UIKit_iOS

final class InfoPopupViewLayout: SCSingleActionLayoutView {
    let bannerContainer: UIView = .create { view in
        view.backgroundColor = .clear
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .boldTitle3Primary)
        label.numberOfLines = 0
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.numberOfLines = 0
    }

    let featuresStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.stackViewSpacing
        view.distribution = .fill
        view.alignment = .top
    }

    let infoStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.stackViewSpacing
        view.distribution = .fill
        view.alignment = .leading
    }

    let additionalInfoLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.numberOfLines = 0
    }

    let skipButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    var mainActionButton: TriangularedButton {
        genericActionView
    }

    private var separatorView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()

        bannerContainer.layoutIfNeeded()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins.top = Constants.topMargin

        addArrangedSubview(bannerContainer, spacingAfter: Constants.bannerToTitle)

        bannerContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.bannerInitialHeight)
        }

        addArrangedSubview(titleLabel, spacingAfter: Constants.titleToSubtitle)
        addArrangedSubview(subtitleLabel, spacingAfter: Constants.subtitleToFeatures)
        addArrangedSubview(featuresStackView, spacingAfter: Constants.featuresToSeparator)

        separatorView = createSeparator()
        addArrangedSubview(separatorView!, spacingAfter: Constants.separatorToInfo)

        addArrangedSubview(infoStackView, spacingAfter: Constants.infoToAdditional)
        addArrangedSubview(additionalInfoLabel)

        setupSkipButton()
    }

    override func setupStyle() {
        super.setupStyle()

        mainActionButton.applyDefaultStyle()
    }
}

// MARK: - Private

private extension InfoPopupViewLayout {
    func setupSkipButton() {
        addSubview(skipButton)

        skipButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(mainActionButton.snp.top).offset(-Constants.buttonsSpacing)
            make.height.equalTo(UIConstants.actionHeight)
        }

        skipButton.isHidden = true
    }

    func createSeparator() -> UIView {
        let separator = UIView.createSeparator()

        separator.snp.makeConstraints { make in
            make.height.equalTo(Constants.separatorHeight)
        }

        return separator
    }

    func addFeatureView(_ feature: InfoPopupViewModel.Feature) {
        let featureView: GenericPairValueView<UIView, UILabel> = .create { view in
            view.makeHorizontal()

            let emojiLabel = UILabel()
            emojiLabel.apply(style: .title3Primary)
            emojiLabel.textAlignment = .left

            view.fView.addSubview(emojiLabel)

            emojiLabel.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
                make.height.equalTo(Constants.emojiLabelHeight)
            }

            view.sView.apply(style: .footnotePrimary)
            view.sView.numberOfLines = 0
            view.sView.textAlignment = .left

            view.spacing = Constants.featureIconToText

            emojiLabel.text = feature.emoji
            view.sView.text = feature.text
        }

        featuresStackView.addArrangedSubview(featureView)
    }

    func addInfoItemView(_ infoItem: InfoPopupViewModel.InfoItem) {
        let infoView: IconDetailsView = .create { view in
            view.detailsLabel.apply(style: .footnoteSecondary)
            view.detailsLabel.numberOfLines = 0
            view.spacing = Constants.infoIconToText
            view.iconWidth = Constants.iconWidth
        }

        let icon: UIImage? = switch infoItem.icon {
        case .history:
            R.image.iconHistoryGray18()
        case .migration:
            R.image.iconStarGray18()
        case let .custom(image):
            image
        }

        infoView.imageView.image = icon
        infoView.detailsLabel.text = infoItem.text

        infoStackView.addArrangedSubview(infoView)
    }

    func clearStacks() {
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        infoStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func updateSkipButtonVisibility(hasSkipButton: Bool) {
        skipButton.isHidden = !hasSkipButton

        if hasSkipButton {
            containerView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.bottom.equalTo(skipButton.snp.top).offset(-8.0)
            }
        } else {
            containerView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.bottom.equalTo(mainActionButton.snp.top).offset(-8.0)
            }
        }
    }
}

// MARK: - Internal

extension InfoPopupViewLayout {
    func bind(_ viewModel: InfoPopupViewModel) {
        titleLabel.text = viewModel.title

        if let subtitle = viewModel.subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }

        clearStacks()
        viewModel.features.forEach { addFeatureView($0) }
        viewModel.infoItems.forEach { addInfoItemView($0) }

        let hasInfoItems = !viewModel.infoItems.isEmpty
        separatorView?.isHidden = !hasInfoItems
        infoStackView.isHidden = !hasInfoItems

        if let additionalInfo = viewModel.additionalInfo {
            additionalInfoLabel.text = additionalInfo
            additionalInfoLabel.isHidden = false
        } else {
            additionalInfoLabel.isHidden = true
        }

        mainActionButton.imageWithTitleView?.title = viewModel.mainActionTitle

        if let skipTitle = viewModel.skipActionTitle {
            skipButton.imageWithTitleView?.title = skipTitle
            updateSkipButtonVisibility(hasSkipButton: true)
        } else {
            updateSkipButtonVisibility(hasSkipButton: false)
        }
    }

    func updateBannerHeight(_ height: CGFloat) {
        bannerContainer.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
        stackView.layoutIfNeeded()
    }
}

// MARK: - Constants

private extension InfoPopupViewLayout {
    enum Constants {
        static let topMargin: CGFloat = 12
        static let bannerToTitle: CGFloat = 16
        static let titleToSubtitle: CGFloat = 4
        static let subtitleToFeatures: CGFloat = 17
        static let featuresToSeparator: CGFloat = 13
        static let separatorToInfo: CGFloat = 10
        static let infoToAdditional: CGFloat = 10
        static let stackViewSpacing: CGFloat = 10
        static let featureIconToText: CGFloat = 16
        static let infoIconToText: CGFloat = 16
        static let bannerInitialHeight: CGFloat = 0
        static let separatorHeight: CGFloat = 1
        static let emojiLabelHeight: CGFloat = 24
        static let iconWidth: CGFloat = 18
        static let buttonsSpacing: CGFloat = 12
    }
}
