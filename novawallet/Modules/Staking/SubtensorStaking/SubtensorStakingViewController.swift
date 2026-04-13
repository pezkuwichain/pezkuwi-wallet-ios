import UIKit
import BigInt

final class SubtensorStakingViewController: UIViewController, SubtensorStakingViewProtocol {
    private let presenter: SubtensorStakingPresenterProtocol

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let stakeButton = UIButton(type: .system)

    var controller: UIViewController { self }

    init(presenter: SubtensorStakingPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO(localization): en.lproj keys exist (staking.subtensor.*) — wire via
        // R.string(preferredLanguages:).localizable.stakingSubtensor*() once a LocalizationManager is
        // injected into this VIPER module. Hardcoded strings are acceptable for v1 manual QA.
        title = "TAO staking"
        view.backgroundColor = .systemBackground
        setupLayout()
        presenter.setup()
    }

    private func setupLayout() {
        // TODO(localization): en.lproj keys exist (staking.subtensor.*) — wire via
        // R.string(preferredLanguages:).localizable.stakingSubtensor*() once a LocalizationManager is
        // injected into this VIPER module. Hardcoded strings are acceptable for v1 manual QA.
        titleLabel.text = "TAO staking"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "Loading validators..."
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        stakeButton.setTitle("Stake", for: .normal)
        stakeButton.addTarget(self, action: #selector(didTapStake), for: .touchUpInside)
        stakeButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(stakeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            stakeButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 32),
            stakeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func didTapStake() {
        presenter.didTapStake()
    }

    // MARK: - SubtensorStakingViewProtocol

    func didReceive(validators: [SubtensorValidator]) {
        // TODO(localization): en.lproj keys exist (staking.subtensor.*) — wire via
        // R.string(preferredLanguages:).localizable.stakingSubtensor*() once a LocalizationManager is
        // injected into this VIPER module. Hardcoded strings are acceptable for v1 manual QA.
        if validators.isEmpty {
            statusLabel.text = "No validators available"
        } else {
            let count = validators.count
            statusLabel.text = "Loaded \(count) validators"
        }
    }

    func didReceive(positions: [SubtensorStakePosition]) {
        // v1: no positions UI yet. This callback lets us confirm the data
        // path works end-to-end during manual QA.
        _ = positions
    }

    func didReceive(minDelegation: BigUInt) {
        _ = minDelegation
    }

    func didReceiveStatus(_ status: String) {
        statusLabel.text = status
    }
}
