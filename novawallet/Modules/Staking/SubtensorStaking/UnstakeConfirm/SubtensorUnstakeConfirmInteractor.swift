import Foundation
import SubstrateSdk
import BigInt
import Operation_iOS

final class SubtensorUnstakeConfirmInteractor {
    weak var presenter: SubtensorUnstakeConfirmInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let hotkey: AccountId
    let netuid: UInt16
    let amount: BigUInt
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let signer: SigningWrapperProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private(set) var extrinsicSubscriptionId: UInt16?

    /// AMM spot price (TAO per alpha) for subnet unstake. nil for root.
    private(set) var spotPriceTaoPerAlpha: Double?
    private(set) var subnetTaoReserve: UInt64 = 0
    private(set) var subnetAlphaInReserve: UInt64 = 0

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        hotkey: AccountId,
        netuid: UInt16,
        amount: BigUInt,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signer: SigningWrapperProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.hotkey = hotkey
        self.netuid = netuid
        self.amount = amount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.signer = signer
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        cancelExtrinsicSubscriptionIfNeeded()
    }

    private func subscribeAccountBalance() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    private func subscribePriceIfNeeded() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
        }
    }

    private func cancelExtrinsicSubscriptionIfNeeded() {
        if let extrinsicSubscriptionId = extrinsicSubscriptionId {
            extrinsicService.cancelExtrinsicWatch(for: extrinsicSubscriptionId)
            self.extrinsicSubscriptionId = nil
        }
    }

    private func buildExtrinsicClosure() -> ExtrinsicBuilderClosure {
        let runtimeCall = SubtensorExtrinsicBuilder.buildRemoveStakeLimit(
            hotkey: hotkey,
            netuid: netuid,
            amount: amount,
            slippage: SubtensorStakingConstants.defaultSlippage,
            spotPriceTaoPerAlpha: spotPriceTaoPerAlpha
        )

        return { builder in
            try builder.adding(call: runtimeCall)
        }
    }

    /// Fetch AMM reserves for subnet limit_price + TAO-received estimate.
    /// Root subnet skips this (no AMM, 1:1).
    private func fetchAMMPriceIfNeeded() {
        guard netuid != SubtensorStakingConstants.rootNetuid else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let reserves = try await SubtensorSubnetFetcher.fetchSubnetReserves(
                    netuid: self.netuid
                )
                self.subnetTaoReserve = reserves.taoReserve
                self.subnetAlphaInReserve = reserves.alphaInReserve
                if reserves.alphaInReserve > 0 {
                    self.spotPriceTaoPerAlpha = Double(reserves.taoReserve) / Double(reserves.alphaInReserve)
                }
                self.presenter?.didReceiveAMMPrice(
                    spotPrice: self.spotPriceTaoPerAlpha,
                    taoReserve: reserves.taoReserve,
                    alphaInReserve: reserves.alphaInReserve
                )
            } catch {
                Logger.shared.error("SubtensorUnstakeConfirm: AMM price fetch failed — \(error)")
            }
        }
    }

    private func doConfirmExtrinsic() {
        let builderClosure = buildExtrinsicClosure()

        let subscriptionIdClosure: ExtrinsicSubscriptionIdClosure = { [weak self] subscriptionId in
            self?.extrinsicSubscriptionId = subscriptionId
            return self != nil
        }

        let notificationClosure: ExtrinsicSubscriptionStatusClosure = { [weak self] result in
            switch result {
            case let .success(updateModel):
                if case .inBlock = updateModel.statusUpdate.extrinsicStatus {
                    self?.cancelExtrinsicSubscriptionIfNeeded()
                    if let coldkey = self?.selectedAccount.chainAccount.accountId {
                        Task { await SubtensorPositionCache.shared.invalidate(coldkey: coldkey) }
                    }
                    self?.presenter?.didCompleteExtrinsicSubmission(
                        for: .success(updateModel.extrinsicSubmittedModel)
                    )
                }
            case let .failure(error):
                self?.cancelExtrinsicSubscriptionIfNeeded()
                self?.presenter?.didCompleteExtrinsicSubmission(for: .failure(error))
            }
        }

        extrinsicService.submitAndWatch(
            builderClosure,
            signer: signer,
            runningIn: .main,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )
    }
}

// MARK: - SubtensorUnstakeConfirmInteractorInputProtocol

extension SubtensorUnstakeConfirmInteractor: SubtensorUnstakeConfirmInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        subscribeAccountBalance()
        subscribePriceIfNeeded()
        fetchAMMPriceIfNeeded()
    }

    func estimateFee() {
        let builderClosure = buildExtrinsicClosure()
        let identifier = "unstake-" + hotkey.toHex() + "-\(netuid)-\(amount)"

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: builderClosure
        )
    }

    func confirm() {
        doConfirmExtrinsic()
    }
}

// MARK: - Wallet subscription

extension SubtensorUnstakeConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

// MARK: - Price subscription

extension SubtensorUnstakeConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

// MARK: - Fee proxy delegate

extension SubtensorUnstakeConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFee(result)
    }
}

// MARK: - Currency

extension SubtensorUnstakeConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
