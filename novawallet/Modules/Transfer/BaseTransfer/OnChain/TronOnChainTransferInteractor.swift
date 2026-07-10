import Foundation
import BigInt
import Operation_iOS

/// Mirrors `EvmOnChainTransferInteractor`'s role (shared setup/fee-estimation base for both the
/// Setup and Confirm screens) for the Tron send path.
class TronOnChainTransferInteractor: OnChainTransferBaseInteractor {
    let feeProxy: TronTransactionFeeProxyProtocol
    let transactionService: TronTransactionServiceProtocol
    let ownerAddress: AccountAddress

    private(set) var transferType: TronTransferType?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        ownerAddress: AccountAddress,
        feeProxy: TronTransactionFeeProxyProtocol,
        transactionService: TronTransactionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.ownerAddress = ownerAddress
        self.feeProxy = feeProxy
        self.transactionService = transactionService

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationQueue: operationQueue
        )

        self.currencyManager = currencyManager
    }

    private func provideMinBalance() {
        // Tron has no existential-deposit-style minimum balance concept for either TRX or TRC20
        // tokens (an account can hold any nonzero amount, or exactly zero, indefinitely) - mirrors
        // `EvmOnChainTransferInteractor.provideMinBalance()`'s identical reasoning for EVM assets.
        presenter?.didReceiveSendingAssetExistence(.init(minBalance: 0, isSelfSufficient: true))
        presenter?.didReceiveUtilityAssetMinBalance(0)
    }

    private func continueSetup() {
        setupSendingAssetBalanceProvider()
        setupUtilityAssetBalanceProviderIfNeeded()
        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
    }

    override func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(optBalance):
            let balance = optBalance ??
                AssetBalance.createZero(
                    for: ChainAssetId(chainId: chainId, assetId: assetId),
                    accountId: accountId
                )

            if asset.assetId == assetId {
                presenter?.didReceiveSendingAssetSenderBalance(balance)
            } else if chain.utilityAssets().first?.assetId == assetId {
                presenter?.didReceiveUtilityAssetSenderBalance(balance)
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension TronOnChainTransferInteractor {
    func setup() {
        if asset.isTronNative {
            transferType = .native

            continueSetup()
        } else if let contractAddress = asset.trc20ContractAddress {
            transferType = .trc20(contractAddress: contractAddress)

            continueSetup()
        } else {
            transferType = nil
            presenter?.didReceiveError(CommonError.dataCorruption)
        }
    }

    func estimateFee(for amount: OnChainTransferAmount<BigUInt>, recepient: AccountId?) {
        do {
            guard let transferType = transferType else {
                return
            }

            // A placeholder recipient (as opposed to failing outright) matches
            // `EvmOnChainTransferInteractor.estimateFee`'s identical approach for showing a fee
            // preview before the user has entered a real recipient. Unlike an EVM/ERC20 transfer,
            // Tron's `to_address` for a native transfer does NOT need to already be activated
            // on-chain (sending TRX to a brand-new address is exactly how it gets activated), so a
            // dummy never-used address is safe to build against here. For a TRC20 transfer this is
            // also the *conservative* choice: crediting a recipient's balance for the very first
            // time (a fresh storage slot) typically costs at least as much TVM energy as crediting
            // an existing balance, so estimating against a never-used address never under-estimates
            // the fee relative to the real (possibly already-holding) recipient.
            let recepientAccountId = recepient ?? AccountId.nonzeroAccountId(of: chain.accountIdSize)
            let recepientAddress = try recepientAccountId.toAddress(using: chain.chainFormat)

            let identifier = String(amount.value) + "-" + recepientAccountId.toHex() + "-" + amount.name

            feeProxy.estimateFee(
                using: transactionService,
                reuseIdentifier: identifier,
                type: transferType,
                amount: amount.value,
                recipient: recepientAddress
            )
        } catch {
            presenter?.didReceiveFee(result: .failure(error))
        }
    }

    func requestFeePaymentAvailability(for _: ChainAsset) {
        // Tron has no custom-fee-asset mechanism (fees are always burned in native TRX, whether
        // sending TRX or a TRC20 token) - mirrors `EvmOnChainTransferInteractor`'s identical stance
        // for EVM chains.
        presenter?.didReceiveCustomAssetFeeAvailable(false)
    }

    func change(recepient: AccountId?) {
        guard let recepient = recepient else {
            return
        }

        // We don't track Tron balances for the recipient beyond a synthetic zero (same rationale
        // as `EvmOnChainTransferInteractor.change(recepient:)`): there's no existential deposit or
        // minimum-balance concept to validate the recipient against.
        let assetZeroBalance = AssetBalance.createZero(
            for: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            accountId: recepient
        )

        presenter?.didReceiveSendingAssetRecepientBalance(assetZeroBalance)

        if !isUtilityTransfer, let utilityChainAssetId = chain.utilityChainAssetId() {
            let utilityZeroBalance = AssetBalance.createZero(for: utilityChainAssetId, accountId: recepient)
            presenter?.didReceiveUtilityAssetRecepientBalance(utilityZeroBalance)
        }
    }
}

extension TronOnChainTransferInteractor: TronTransactionFeeProxyDelegate {
    func didReceiveTronFee(result: Result<TronFeeModel, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(model):
            let feeValue = ExtrinsicFee(amount: model.fee, payer: nil, weight: .zero)
            // No extra `validationProvider` (unlike EVM's `EvmGasPriceValidationProvider`, which
            // re-checks a fluctuating gas-price auction wasn't stale by submission time): Tron has
            // no comparable auction, and the one validation Tron sending actually needs - can the
            // sender afford the estimated fee out of their native TRX balance - is already fully
            // covered generically by `canPayFeeSpendingAmountInPlank`/`canPayFee` in
            // `BaseDataValidatorFactory`, wired in via `OnChainTransferPresenter.baseValidators()`
            // regardless of asset family.
            let feeModel = FeeOutputModel(value: feeValue, validationProvider: nil)
            presenter?.didReceiveFee(result: .success(feeModel))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}
