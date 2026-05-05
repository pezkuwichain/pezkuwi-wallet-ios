import UIKit
import SnapKit

/// Layout for the Subtensor unstake setup screen. Mirrors
/// `SubtensorStakeSetupViewLayout` but with the validator section read-only
/// (pre-filled from the selected position) and a "Your stake" row instead
/// of the "Min stake" row.
final class SubtensorUnstakeSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let validatorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    let validatorTableView: StackTableView = {
        let view = StackTableView()
        view.cellHeight = 34.0
        view.contentInsets = UIEdgeInsets(top: 7.0, left: 16.0, bottom: 7.0, right: 16.0)
        return view
    }()

    let validatorActionView = StackAccountSelectionCell()

    /// Swap-style header: "Amount" left, "Max: 0.30312 SN8" right (the
    /// "Max:" portion is tappable and styled with `.footnoteAccentText`).
    let amountView = SwapSetupTitleView(frame: .zero)

    let amountInputView = NewAmountInputView()

    let positionView = TitleAmountView.dark()

    let networkFeeView = UIFactory.default.createNetworkFeeView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(validatorTitleLabel)
        validatorTitleLabel.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(validatorTableView)
        validatorTableView.addArrangedSubview(validatorActionView)

        containerView.stackView.setCustomSpacing(8.0, after: validatorTableView)

        containerView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(positionView)

        containerView.stackView.addArrangedSubview(networkFeeView)
    }
}
