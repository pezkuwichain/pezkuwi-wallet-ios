import Foundation
import BigInt
import Operation_iOS

/// Interactor for the Subtensor stake setup flow. Surfaces:
///   - active-validator list + min-delegation runtime constant (from
///     `SubtensorStakingService`)
///   - live `AssetBalance` via `WalletLocalSubscriptionFactoryProtocol`
///   - live `PriceData` via `PriceProviderFactoryProtocol`
///
/// v1 deliberately does NOT estimate extrinsic fees here — that lands in
/// Phase B alongside confirm / submit. The wallet-local + price subscriptions
/// match the shape of `ParaStkStakeSetupInteractor` so the presenter can use
/// Nova's canonical `BalanceViewModelFactory` pipeline.
final class SubtensorStakeSetupInteractor {
    weak var presenter: SubtensorStakeSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let service: SubtensorStakingService
    let validatorProvider: SubtensorValidatorProvider
    let netuid: UInt16

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var setupTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        service: SubtensorStakingService,
        validatorProvider: SubtensorValidatorProvider,
        currencyManager: CurrencyManagerProtocol,
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.service = service
        self.validatorProvider = validatorProvider
        self.netuid = netuid
        self.currencyManager = currencyManager
    }

    deinit {
        setupTask?.cancel()
        refreshTask?.cancel()
    }

    private func performAssetBalanceSubscription() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    private func performPriceSubscription() {
        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func fetchValidatorsAndMinDelegation() {
        setupTask?.cancel()
        setupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                async let validators = service.fetchActiveValidators(
                    netuid: netuid
                )
                async let minDelegation = service.fetchMinDelegation()

                let (fetchedValidators, fetchedMin) = try await(validators, minDelegation)
                guard !Task.isCancelled else { return }

                presenter?.didReceive(validators: fetchedValidators)
                presenter?.didReceive(minDelegation: fetchedMin)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }
}

// MARK: - SubtensorStakeSetupInteractorInputProtocol

extension SubtensorStakeSetupInteractor: SubtensorStakeSetupInteractorInputProtocol {
    func setup() {
        performAssetBalanceSubscription()
        performPriceSubscription()
        fetchValidatorsAndMinDelegation()
    }

    func refreshValidators() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let validators = try await service.fetchActiveValidators(
                    netuid: netuid
                )
                guard !Task.isCancelled else { return }
                presenter?.didReceive(validators: validators)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }
}

// MARK: - Wallet subscription

extension SubtensorStakeSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

// MARK: - Price subscription

extension SubtensorStakeSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

// MARK: - Currency observation

extension SubtensorStakeSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, chainAsset.asset.priceId != nil else { return }
        performPriceSubscription()
    }
}
