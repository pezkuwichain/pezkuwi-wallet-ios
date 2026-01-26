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

    private var subtitleSpacingConstraint: NSLayoutConstraint?
    private var additionalInfoSpacingConstraint: NSLayoutConstraint?

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
        addArrangedSubview(featuresStackView, spacingAfter: Constants.featuresToInfo)
        addArrangedSubview(additionalInfoLabel)

        setupActionButtonsLayout()
    }

    override func setupStyle() {
        super.setupStyle()

        mainActionButton.applyDefaultStyle()
    }
}

// MARK: - Private

private extension InfoPopupViewLayout {
    func setupActionButtonsLayout() {
        let buttonsContainer = UIView()

        buttonsContainer.addSubview(mainActionButton)
        buttonsContainer.addSubview(skipButton)

        mainActionButton.snp.remakeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(Constants.buttonHeight)
        }

        skipButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(mainActionButton.snp.bottom).offset(Constants.buttonsSpacing)
            make.height.equalTo(Constants.buttonHeight)
        }

        addSubview(buttonsContainer)

        buttonsContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
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

    func clearFeatures() {
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
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

        clearFeatures()
        viewModel.features.forEach { addFeatureView($0) }

        if let additionalInfo = viewModel.additionalInfo {
            additionalInfoLabel.text = additionalInfo
            additionalInfoLabel.isHidden = false
        } else {
            additionalInfoLabel.isHidden = true
        }

        mainActionButton.imageWithTitleView?.title = viewModel.mainActionTitle

        if let skipTitle = viewModel.skipActionTitle {
            skipButton.imageWithTitleView?.title = skipTitle
            skipButton.isHidden = false
        } else {
            skipButton.isHidden = true
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
        static let featuresToInfo: CGFloat = 13
        static let stackViewSpacing: CGFloat = 10
        static let featureIconToText: CGFloat = 16
        static let bannerInitialHeight: CGFloat = 0
        static let emojiLabelHeight: CGFloat = 24
        static let buttonHeight: CGFloat = 52
        static let buttonsSpacing: CGFloat = 12
    }
}
