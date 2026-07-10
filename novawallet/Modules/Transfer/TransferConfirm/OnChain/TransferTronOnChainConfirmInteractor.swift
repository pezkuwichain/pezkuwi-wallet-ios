import UIKit
import BigInt
import Operation_iOS

final class TransferTronOnChainConfirmInteractor: TronOnChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol

    var submitionPresenter: TransferConfirmOnChainInteractorOutputProtocol? {
        presenter as? TransferConfirmOnChainInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        ownerAddress: AccountAddress,
        feeProxy: TronTransactionFeeProxyProtocol,
        transactionService: TronTransactionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            ownerAddress: ownerAddress,
            feeProxy: feeProxy,
            transactionService: transactionService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private func persistExtrinsicAndComplete(details: PersistTransferDetails, type: TronTransferType) {
        persistExtrinsicService.saveTransfer(
            source: type.transactionSource,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            details: details,
            runningIn: .main
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .success:
                self.eventCenter.notify(with: WalletTransactionListUpdated())
                self.submitionPresenter?.didCompleteSubmition(by: nil)
            case let .failure(error):
                self.presenter?.didReceiveError(error)
            }
        }
    }
}

extension TransferTronOnChainConfirmInteractor: TransferConfirmOnChainInteractorInputProtocol {
    func submit(amount: OnChainTransferAmount<BigUInt>, recepient: AccountAddress, lastFee: BigUInt?) {
        guard let transferType = transferType else {
            presenter?.didReceiveError(CommonError.dataCorruption)
            return
        }

        let sender = ownerAddress

        transactionService.submit(
            for: transferType,
            amount: amount.value,
            recipient: recepient,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(txId):
                guard persistenceFilter.canPersistExtrinsic(for: selectedAccount) else {
                    submitionPresenter?.didCompleteSubmition(by: nil)
                    return
                }

                if let txHashData = try? Data(hexString: txId) {
                    let details = PersistTransferDetails(
                        sender: sender,
                        receiver: recepient,
                        amount: amount.value,
                        txHash: txHashData,
                        callPath: transferType.callCodingPath,
                        fee: lastFee,
                        feeAssetId: nil
                    )

                    persistExtrinsicAndComplete(details: details, type: transferType)
                } else {
                    submitionPresenter?.didCompleteSubmition(by: nil)
                }

            case let .failure(error):
                presenter?.didReceiveError(error)
            }
        }
    }
}
