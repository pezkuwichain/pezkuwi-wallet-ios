import UIKit
import Foundation_iOS
import SubstrateSdk

/// Displays a scrollable list of Bittensor subnets. Each row shows
/// the subnet name, netuid, TAO reserve, and spot price (TAO per alpha).
/// The user taps a row → the callback fires with the selected netuid.
///
/// Data is fetched via direct RPC calls to the chain — no indexer needed.
/// Uses `ChainRegistryFacade` for the WebSocket connection.
final class SubtensorSubnetPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let chainAsset: ChainAsset
    private let onSelection: (SubtensorSubnetInfo) -> Void

    private var subnets: [SubtensorSubnetInfo] = []
    private var isLoading = true

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = R.color.colorSecondaryScreenBackground()
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 72
        tv.register(SubtensorSubnetCell.self, forCellReuseIdentifier: SubtensorSubnetCell.reuseId)
        return tv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    init(
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        onSelection: @escaping (SubtensorSubnetInfo) -> Void
    ) {
        self.chainAsset = chainAsset
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = R.string(preferredLanguages: selectedLocale.rLanguages)
            .localizable.stakingSubtensorSubnetPickerTitle()

        view.backgroundColor = R.color.colorSecondaryScreenBackground()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { $0.center.equalToSuperview() }

        tableView.dataSource = self
        tableView.delegate = self

        fetchSubnets()
    }

    // MARK: - Data fetching

    private func fetchSubnets() {
        activityIndicator.startAnimating()

        Task { @MainActor in
            do {
                let fetched = try await SubtensorSubnetFetcher.fetchAllSubnets(
                    chainId: chainAsset.chain.chainId
                )
                self.subnets = fetched.sorted { $0.taoReserve > $1.taoReserve }
                self.isLoading = false
                self.activityIndicator.stopAnimating()
                self.tableView.reloadData()
            } catch {
                self.isLoading = false
                self.activityIndicator.stopAnimating()
                Logger.shared.error("SubnetPicker: failed to fetch subnets — \(error)")
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        subnets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorSubnetCell.reuseId,
            for: indexPath
        ) as? SubtensorSubnetCell else {
            return UITableViewCell()
        }

        let subnet = subnets[indexPath.row]
        cell.bind(subnet: subnet)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subnet = subnets[indexPath.row]
        onSelection(subnet)
    }
}

// MARK: - Localizable

extension SubtensorSubnetPickerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string(preferredLanguages: selectedLocale.rLanguages)
                .localizable.stakingSubtensorSubnetPickerTitle()
        }
    }
}
