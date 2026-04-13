import UIKit

/// Main TAO staking dashboard. Shows the user's active stake positions
/// (queried live from chain) and provides a path to start new stakes.
final class SubtensorStakingViewController: UIViewController, SubtensorStakingViewProtocol {
    private let presenter: SubtensorStakingPresenterProtocol
    private let rootView = SubtensorStakingViewLayout()

    private var positionViewModels: [SubtensorPositionViewModel] = []

    var controller: UIViewController { self }

    init(presenter: SubtensorStakingPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func loadView() {
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TAO Staking"
        setupNavBar()
        setupTableView()
        rootView.showState(.loading)

        rootView.startStakingButton.addTarget(self, action: #selector(didTapStake), for: .touchUpInside)

        presenter.setup()
    }

    // MARK: - Nav bar

    private func setupNavBar() {
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapStake)
        )
        navigationItem.rightBarButtonItem = addButton
    }

    // MARK: - Table view

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.register(
            SubtensorPositionTableViewCell.self,
            forCellReuseIdentifier: SubtensorPositionTableViewCell.reuseId
        )
    }

    // MARK: - Actions

    @objc private func didTapStake() {
        presenter.didTapStake()
    }

    // MARK: - SubtensorStakingViewProtocol

    func didReceive(positions: [SubtensorPositionViewModel]) {
        positionViewModels = positions
        if positions.isEmpty {
            rootView.showState(.empty)
        } else {
            rootView.showState(.loaded)
            rootView.tableView.reloadData()
        }
    }

    func didReceiveStatus(_ status: String) {
        switch status {
        case "loading":
            rootView.showState(.loading)
        default:
            break
        }
    }
}

// MARK: - UITableViewDataSource

extension SubtensorStakingViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int { 1 }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        positionViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorPositionTableViewCell.reuseId,
            for: indexPath
        ) as! SubtensorPositionTableViewCell // swiftlint:disable:this force_cast
        cell.bind(viewModel: positionViewModels[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SubtensorStakingViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        positionViewModels.isEmpty ? 0 : 48
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard !positionViewModels.isEmpty else { return nil }
        let header = StakingSectionHeaderView()
        header.titleLabel.text = "Your Stakes"
        return header
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        // P1: tap → manage / unstake flow. No-op for now.
        tableView(rootView.tableView, didDeselectRowAt: indexPath)
    }

    func tableView(_: UITableView, didDeselectRowAt indexPath: IndexPath) {
        rootView.tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Section header

private final class StakingSectionHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }
}
