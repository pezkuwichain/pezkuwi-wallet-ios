import UIKit
import UIKit_iOS
import SnapKit

/// The Pezkuwi citizenship dashboard card — collapsed pill / expanded card, matching the exact
/// interaction spec of the Android sibling app's `item_pezkuwi_dashboard.xml` +
/// `PezkuwiDashboardAdapter.PezkuwiDashboardHolder`.
final class PezkuwiDashboardCardView: UIView {
    weak var delegate: PezkuwiDashboardCardViewDelegate?

    // MARK: Collapsed pill

    private let collapsedBar: UIControl = {
        let view = UIControl()
        view.backgroundColor = R.color.colorButtonBackgroundPrimary()
        view.layer.cornerRadius = PezkuwiDashboardMeasurement.collapsedCornerRadius
        view.clipsToBounds = true
        return view
    }()

    private let collapsedFlameIcon: UIImageView = {
        let view = UIImageView(image: PezkuwiDashboardCardView.flameIcon)
        view.contentMode = .scaleAspectFit
        view.tintColor = .white
        return view
    }()

    private let collapsedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Trust Score"
        label.textColor = .white
        label.font = .semiBoldFootnote
        return label
    }()

    private let collapsedTrustValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .semiBoldFootnote
        return label
    }()

    private let collapsedChevron: UIImageView = {
        let view = UIImageView(image: R.image.iconSmallArrowDown())
        view.tintColor = .white
        view.contentMode = .scaleAspectFit
        return view
    }()

    // MARK: Expanded content

    private let expandedContent: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlockBackground()
        view.layer.cornerRadius = PezkuwiDashboardMeasurement.cardCornerRadius
        view.layer.borderWidth = 1.0
        view.layer.borderColor = R.color.colorDivider()?.cgColor
        view.clipsToBounds = true
        return view
    }()

    private let expandedFlameIcon: UIImageView = {
        let view = UIImageView(image: PezkuwiDashboardCardView.flameIcon)
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Pezkuwi"
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        return label
    }()

    private let rolesView = PezkuwiDashboardRoleTagsView()

    private let welatiCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPositive()
        label.font = .boldTitle2
        label.textAlignment = .right
        return label
    }()

    private let welatiSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Hejmara Kurd Le Cihane"
        label.textColor = R.color.colorTextSecondary()
        label.font = .caption2
        label.textAlignment = .right
        return label
    }()

    private let collapseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(R.image.iconArrowUp(), for: .normal)
        button.tintColor = R.color.colorTextSecondary()
        return button
    }()

    private let trustScoreLabel: UILabel = {
        let label = UILabel()
        label.text = "Trust Score"
        label.textColor = R.color.colorTextSecondary()
        label.font = .caption1
        return label
    }()

    private let trustScoreValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextWarning()
        label.font = .semiBoldSubheadline
        return label
    }()

    let startTrackingButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.imageWithTitleView?.title = "Start Tracking"
        button.isHidden = true
        return button
    }()

    let applyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let signButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDestructiveDefaultStyle()
        button.imageWithTitleView?.title = "Sign"
        return button
    }()

    let shareButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        button.imageWithTitleView?.title = "Share Referral Link"
        return button
    }()

    private var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupHandlers()
        applyExpandedState(animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: PezkuwiDashboardViewModel) {
        collapsedTrustValueLabel.text = viewModel.trustScore
        trustScoreValueLabel.text = viewModel.trustScore
        welatiCountLabel.text = viewModel.welatiCount
        rolesView.bind(roles: viewModel.roles)

        let buttonsState = PezkuwiDashboardButtonsState(citizenshipStatus: viewModel.citizenshipStatus)
        bind(buttonsState: buttonsState)

        let showTracking = !viewModel.isTrackingScore && viewModel.citizenshipStatus == .approved
        startTrackingButton.isHidden = !showTracking
    }

    func bind(trackingLoading: Bool) {
        startTrackingButton.isUserInteractionEnabled = !trackingLoading
        startTrackingButton.imageWithTitleView?.title = trackingLoading ? "..." : "Start Tracking"
        startTrackingButton.invalidateLayout()
    }

    /// Sets expand/collapse state without animation — used for the initial bind on cell creation,
    /// so recycling/rebinding never triggers an unwanted animation (mirrors Android's
    /// `PezkuwiDashboardHolder.bind` comment: "animation is only for user-initiated toggles").
    func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }

        isExpanded = expanded
        applyExpandedState(animated: false)
    }

    var currentHeight: CGFloat {
        isExpanded ? PezkuwiDashboardMeasurement.expandedHeight : PezkuwiDashboardMeasurement.collapsedHeight
    }
}

// MARK: - Private

private extension PezkuwiDashboardCardView {
    static var flameIcon: UIImage? {
        R.image.iconFire() ?? UIImage(systemName: "flame.fill")
    }

    func bind(buttonsState: PezkuwiDashboardButtonsState) {
        applyButton.imageWithTitleView?.title = buttonsState.applyTitleIsApprove
            ? "Approve Referral"
            : "Apply & Actions (KYC)"
        applyButton.invalidateLayout()

        signButton.isHidden = !buttonsState.signVisible
        signButton.isUserInteractionEnabled = buttonsState.signEnabled
        signButton.alpha = buttonsState.signEnabled ? 1.0 : 0.4

        shareButton.isUserInteractionEnabled = buttonsState.shareEnabled
        shareButton.alpha = buttonsState.shareEnabled ? 1.0 : 0.4
    }

    func setupHandlers() {
        collapsedBar.addTarget(self, action: #selector(actionExpand), for: .touchUpInside)
        collapseButton.addTarget(self, action: #selector(actionCollapse), for: .touchUpInside)
        applyButton.addTarget(self, action: #selector(actionApply), for: .touchUpInside)
        signButton.addTarget(self, action: #selector(actionSign), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(actionShare), for: .touchUpInside)
        startTrackingButton.addTarget(self, action: #selector(actionStartTracking), for: .touchUpInside)
    }

    @objc func actionExpand() {
        isExpanded = true
        applyExpandedState(animated: true)
        delegate?.pezkuwiDashboardCardDidToggleExpanded(self)
    }

    @objc func actionCollapse() {
        isExpanded = false
        applyExpandedState(animated: true)
        delegate?.pezkuwiDashboardCardDidToggleExpanded(self)
    }

    @objc func actionApply() {
        delegate?.pezkuwiDashboardCardDidTapApply(self)
    }

    @objc func actionSign() {
        delegate?.pezkuwiDashboardCardDidTapSign(self)
    }

    @objc func actionShare() {
        delegate?.pezkuwiDashboardCardDidTapShare(self)
    }

    @objc func actionStartTracking() {
        delegate?.pezkuwiDashboardCardDidTapStartTracking(self)
    }

    func applyExpandedState(animated: Bool) {
        let apply = { [weak self] in
            guard let self else { return }

            collapsedBar.isHidden = isExpanded
            expandedContent.isHidden = !isExpanded
        }

        if animated {
            UIView.transition(
                with: self,
                duration: 0.2,
                options: .transitionCrossDissolve,
                animations: apply
            )
        } else {
            apply()
        }
    }

    func setupLayout() {
        addSubview(collapsedBar)
        collapsedBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(PezkuwiDashboardMeasurement.collapsedHeight)
        }

        collapsedBar.addSubview(collapsedFlameIcon)
        collapsedFlameIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        collapsedBar.addSubview(collapsedChevron)
        collapsedChevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        collapsedBar.addSubview(collapsedTrustValueLabel)
        collapsedTrustValueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(collapsedChevron.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }

        collapsedBar.addSubview(collapsedTitleLabel)
        collapsedTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(collapsedFlameIcon.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(collapsedTrustValueLabel.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }

        addSubview(expandedContent)
        expandedContent.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupExpandedContentLayout()
    }

    func setupExpandedContentLayout() {
        let padding = PezkuwiDashboardMeasurement.contentPadding

        expandedContent.addSubview(expandedFlameIcon)
        expandedFlameIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(padding)
            make.top.equalToSuperview().offset(padding)
            make.width.height.equalTo(40)
        }

        expandedContent.addSubview(collapseButton)
        collapseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-padding)
            make.top.equalToSuperview().offset(padding - 6)
            make.width.height.equalTo(32)
        }

        expandedContent.addSubview(welatiCountLabel)
        welatiCountLabel.snp.makeConstraints { make in
            make.trailing.equalTo(collapseButton.snp.leading).offset(-4)
            make.top.equalToSuperview().offset(padding)
        }

        expandedContent.addSubview(welatiSubtitleLabel)
        welatiSubtitleLabel.snp.makeConstraints { make in
            make.trailing.equalTo(welatiCountLabel.snp.trailing)
            make.top.equalTo(welatiCountLabel.snp.bottom).offset(2)
        }

        expandedContent.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(expandedFlameIcon.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(padding)
            make.trailing.lessThanOrEqualTo(welatiCountLabel.snp.leading).offset(-8)
        }

        expandedContent.addSubview(rolesView)
        rolesView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.trailing.lessThanOrEqualTo(welatiCountLabel.snp.leading).offset(-8)
        }

        expandedContent.addSubview(trustScoreLabel)
        trustScoreLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(padding)
            make.top.equalTo(expandedFlameIcon.snp.bottom).offset(14)
        }

        expandedContent.addSubview(trustScoreValueLabel)
        trustScoreValueLabel.snp.makeConstraints { make in
            make.leading.equalTo(trustScoreLabel.snp.trailing).offset(8)
            make.centerY.equalTo(trustScoreLabel)
        }

        expandedContent.addSubview(startTrackingButton)
        startTrackingButton.snp.makeConstraints { make in
            make.leading.equalTo(trustScoreValueLabel.snp.trailing).offset(8)
            make.centerY.equalTo(trustScoreLabel)
            make.height.equalTo(PezkuwiDashboardMeasurement.trackingButtonHeight)
            make.trailing.lessThanOrEqualToSuperview().offset(-padding)
        }

        expandedContent.addSubview(applyButton)
        applyButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(padding)
            make.top.equalTo(trustScoreLabel.snp.bottom).offset(16)
            make.height.equalTo(PezkuwiDashboardMeasurement.buttonHeight)
        }

        expandedContent.addSubview(signButton)
        signButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(padding)
            make.top.equalTo(applyButton.snp.bottom).offset(8)
            make.height.equalTo(PezkuwiDashboardMeasurement.buttonHeight)
        }

        expandedContent.addSubview(shareButton)
        shareButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(padding)
            make.top.equalTo(signButton.snp.bottom).offset(8)
            make.height.equalTo(PezkuwiDashboardMeasurement.buttonHeight)
            make.bottom.lessThanOrEqualToSuperview().offset(-padding)
        }
    }
}

protocol PezkuwiDashboardCardViewDelegate: AnyObject {
    func pezkuwiDashboardCardDidToggleExpanded(_ view: PezkuwiDashboardCardView)
    func pezkuwiDashboardCardDidTapApply(_ view: PezkuwiDashboardCardView)
    func pezkuwiDashboardCardDidTapSign(_ view: PezkuwiDashboardCardView)
    func pezkuwiDashboardCardDidTapShare(_ view: PezkuwiDashboardCardView)
    func pezkuwiDashboardCardDidTapStartTracking(_ view: PezkuwiDashboardCardView)
}
