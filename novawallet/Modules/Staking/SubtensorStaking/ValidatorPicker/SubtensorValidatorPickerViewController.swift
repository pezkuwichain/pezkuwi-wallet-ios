import UIKit
import SubstrateSdk
import Foundation_iOS
import BigInt

/// Modal view controller that displays a searchable list of Bittensor
/// validators. The caller passes a netuid, an optional pre-fetched validator
/// list, and an `onSelection` callback. v1 only ever passes
/// `SubtensorStakingConstants.rootNetuid`, but the parameter is plumbed
/// through so subnet variants compose without rewrites.
///
/// The picker is intentionally self-contained: it does its own data
/// fetching via `SubtensorValidatorProvider` rather than going through a
/// VIPER interactor/presenter for v1. The closure-based selection keeps
/// integration with the setup screen trivial. If a follow-up needs more
/// state (real APR, sort modes, hand-off to confirm flow), this can be
/// upgraded to a full VIPER module without any caller-side changes.
final class SubtensorValidatorPickerViewController: UIViewController {
    typealias RootViewType = SubtensorValidatorPickerViewLayout

    private let netuid: UInt16
    private let validatorProvider: SubtensorValidatorProvider
    private let onSelection: (SubtensorValidator) -> Void
    private let cellViewModelFactory: SubtensorValidatorCellViewModelFactory

    private var allValidators: [SubtensorValidator] = []
    private var filteredViewModels: [SubtensorValidatorCellViewModel] = []
    private var fetchTask: Task<Void, Never>?

    init(
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid,
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        prefetched: [SubtensorValidator]? = nil,
        onSelection: @escaping (SubtensorValidator) -> Void
    ) {
        self.netuid = netuid
        self.validatorProvider = validatorProvider
        self.cellViewModelFactory = cellViewModelFactory
        self.onSelection = onSelection

        super.init(nibName: nil, bundle: nil)

        if let prefetched, !prefetched.isEmpty {
            allValidators = prefetched
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        fetchTask?.cancel()
    }

    var rootView: RootViewType {
        // swiftlint:disable:next force_cast
        view as! RootViewType
    }

    override func loadView() {
        view = SubtensorValidatorPickerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO(phase-e): R.string.localizable.stakingSubtensorPickerTitle(...)
        title = "Select validator"
        navigationItem.largeTitleDisplayMode = .always

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.register(
            SubtensorValidatorTableViewCell.self,
            forCellReuseIdentifier: SubtensorValidatorTableViewCell.reuseId
        )
        rootView.searchBar.delegate = self
        rootView.retryButton.addTarget(self, action: #selector(actionRetry), for: .touchUpInside)

        if !allValidators.isEmpty {
            applyValidators(allValidators)
        } else {
            loadValidators()
        }
    }

    @objc private func actionRetry() {
        loadValidators()
    }

    private func loadValidators() {
        rootView.showState(.loading)
        fetchTask?.cancel()

        let provider = validatorProvider
        let captureNetuid = netuid

        fetchTask = Task { @MainActor [weak self] in
            do {
                let result = try await provider.fetchValidators(netuid: captureNetuid)
                guard !Task.isCancelled, let self else { return }
                self.allValidators = result
                self.applyValidators(result)
            } catch {
                guard !Task.isCancelled, let self else { return }
                Logger.shared.error("SubtensorValidatorPicker fetch failed: \(error.localizedDescription)")
                self.rootView.showState(.error)
            }
        }
    }

    private func applyValidators(_ validators: [SubtensorValidator]) {
        if validators.isEmpty {
            filteredViewModels = []
            rootView.showState(.empty)
            return
        }

        let query = (rootView.searchBar.text ?? "").trimmingCharacters(in: .whitespaces)
        let matched = filter(validators: validators, query: query)
        filteredViewModels = matched.map { cellViewModelFactory.create(from: $0, netuid: netuid) }
        rootView.tableView.reloadData()
        rootView.showState(filteredViewModels.isEmpty ? .empty : .loaded)
    }

    private func filter(validators: [SubtensorValidator], query: String) -> [SubtensorValidator] {
        guard !query.isEmpty else { return validators }
        let lower = query.lowercased()
        return validators.filter { validator in
            if let name = validator.identity?.lowercased(), name.contains(lower) {
                return true
            }
            return validator.hotkey.toHex().lowercased().contains(lower)
        }
    }
}

// MARK: - UITableViewDataSource

extension SubtensorValidatorPickerViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        filteredViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorValidatorTableViewCell.reuseId,
            for: indexPath
        ) as? SubtensorValidatorTableViewCell ?? SubtensorValidatorTableViewCell(
            style: .default,
            reuseIdentifier: SubtensorValidatorTableViewCell.reuseId
        )

        cell.bind(viewModel: filteredViewModels[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SubtensorValidatorPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let viewModel = filteredViewModels[indexPath.row]
        guard let validator = allValidators.first(where: { $0.hotkey == viewModel.hotkey }) else {
            return
        }
        onSelection(validator)
        dismiss(animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension SubtensorValidatorPickerViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange _: String) {
        applyValidators(allValidators)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        applyValidators(allValidators)
    }
}
