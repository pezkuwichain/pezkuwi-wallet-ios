import UIKit

/// Layout for the TAO staking dashboard screen.
/// Manages three mutually exclusive states: loading, empty, and loaded (shows position list).
final class SubtensorStakingViewLayout: UIView {
    // MARK: - Loading state

    let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = R.color.colorIconSecondary()
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Empty state

    let emptyContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()

    let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "No active stakes"
        label.font = .boldTitle3
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .center
        return label
    }()

    let emptySubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose a validator and delegate TAO to start earning rewards."
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let startStakingButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.imageWithTitleView?.title = "Start Staking"
        return button
    }()

    // MARK: - Loaded state

    let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = R.color.colorSecondaryScreenBackground()
        table.separatorStyle = .singleLine
        table.separatorColor = R.color.colorContainerBorder()
        table.rowHeight = 64
        table.estimatedRowHeight = 64
        table.estimatedSectionHeaderHeight = 48
        table.isHidden = true
        table.tableFooterView = UIView()
        return table
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    // MARK: - Layout

    private func setupLayout() {
        // Loading
        addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Table (loaded state)
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])

        // Empty state
        emptyContainer.addArrangedSubview(emptyTitleLabel)
        emptyContainer.addArrangedSubview(emptySubtitleLabel)
        emptyContainer.addArrangedSubview(startStakingButton)

        startStakingButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            startStakingButton.widthAnchor.constraint(equalToConstant: 220),
            startStakingButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        addSubview(emptyContainer)
        emptyContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            emptyContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            emptyContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    // MARK: - State

    func showState(_ state: ScreenState) {
        switch state {
        case .loading:
            loadingIndicator.startAnimating()
            tableView.isHidden = true
            emptyContainer.isHidden = true
        case .empty:
            loadingIndicator.stopAnimating()
            tableView.isHidden = true
            emptyContainer.isHidden = false
        case .loaded:
            loadingIndicator.stopAnimating()
            tableView.isHidden = false
            emptyContainer.isHidden = true
        }
    }
}

extension SubtensorStakingViewLayout {
    enum ScreenState {
        case loading
        case empty
        case loaded
    }
}
