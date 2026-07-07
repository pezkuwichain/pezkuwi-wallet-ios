import Foundation
import Operation_iOS
import BigInt

/// Periodically polls TronGrid over REST for the native TRX balance and every TRC20 asset
/// configured for a single Tron chain + account, and persists the results into the same
/// `AssetBalance` storage the rest of the wallet UI reads from.
///
/// Unlike the EVM/Substrate balance services, there is no live push mechanism to piggyback on
/// (Tron isn't JSON-RPC/WebSocket at the transport layer - see `ChainModel+Tron.swift`), so this
/// self-reschedules via `syncUp(afterDelay:ignoreIfSyncing:)` after every successful poll, in
/// addition to `BaseSyncService`'s existing exponential-backoff retry-on-failure behavior.
final class TronAccountBalanceSyncService: BaseSyncService {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let accountAddress: AccountAddress
    let assets: [AssetModel]
    let operationFactory: TronGridOperationFactoryProtocol
    let updateHandler: TronBalanceUpdatePersistentHandler
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue
    let pollInterval: TimeInterval

    private let callStore = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        accountAddress: AccountAddress,
        assets: [AssetModel],
        operationFactory: TronGridOperationFactoryProtocol,
        updateHandler: TronBalanceUpdatePersistentHandler,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global(),
        pollInterval: TimeInterval = 30,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.accountAddress = accountAddress
        self.assets = assets
        self.operationFactory = operationFactory
        self.updateHandler = updateHandler
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.workQueue = workQueue
        self.pollInterval = pollInterval

        super.init(logger: logger)
    }

    private func createBalanceFetchWrapper() -> CompoundOperationWrapper<[ChainAssetId: BigUInt]> {
        let assetOperations: [(AssetModel.Id, BaseOperation<BigUInt>)] = assets.compactMap { asset in
            if asset.isTronNative {
                return (asset.assetId, operationFactory.createNativeBalanceOperation(for: accountAddress))
            } else if asset.isTronAsset, let contractAddress = asset.trc20ContractAddress {
                let operation = operationFactory.createTrc20BalanceOperation(
                    ownerAddress: accountAddress,
                    contractAddress: contractAddress
                )
                return (asset.assetId, operation)
            } else {
                return nil
            }
        }

        let mergeOperation = ClosureOperation<[ChainAssetId: BigUInt]> { [chainId] in
            try assetOperations.reduce(into: [ChainAssetId: BigUInt]()) { result, item in
                let (assetId, operation) = item
                let balance = try operation.extractNoCancellableResultData()
                result[ChainAssetId(chainId: chainId, assetId: assetId)] = balance
            }
        }

        assetOperations.forEach { _, operation in
            mergeOperation.addDependency(operation)
        }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: assetOperations.map(\.1)
        )
    }

    private func notifyBalanceChanges(_ changedIds: Set<ChainAssetId>) {
        for chainAssetId in changedIds {
            let event = AssetBalanceChanged(
                chainAssetId: chainAssetId,
                accountId: accountId,
                changes: nil,
                block: nil
            )

            eventCenter.notify(with: event)
        }
    }

    // Two sequential steps rather than one combined `CompoundOperationWrapper`: first fetch the
    // new balances over REST, then (only once that plain `[ChainAssetId: BigUInt]` value is known)
    // build and run the save wrapper. This mirrors how the EVM flow does it (fetch resolves via a
    // JSON-RPC callback into a plain value first, saving is a separate wrapper run afterward in
    // `EvmNativeBalanceUpdateService.handleAndComplete`) rather than needing a "dynamically build
    // an operation from another operation's not-yet-known result" combinator.
    private func handleFetchedBalances(_ balances: [ChainAssetId: BigUInt]) {
        let saveWrapper = updateHandler.createSaveWrapper(balances: balances, accountId: accountId)

        executeCancellable(
            wrapper: saveWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(changedIds):
                completeImmediate(nil)

                if !changedIds.isEmpty {
                    notifyBalanceChanges(changedIds)
                }

                // Dispatched async (not called inline) because this callback runs while `mutex`
                // is already held (see `executeCancellable`'s `dispatchInQueueWhenPossible(_:
                // locking:)`), and `syncUp(afterDelay:ignoreIfSyncing:)` itself acquires the same
                // non-reentrant `NSLock` - calling it inline here would self-deadlock.
                workQueue.async { [weak self] in
                    self?.syncUp(afterDelay: pollInterval, ignoreIfSyncing: false)
                }
            case let .failure(error):
                completeImmediate(error)
            }
        }
    }

    override func performSyncUp() {
        guard !assets.isEmpty else {
            completeImmediate(nil)
            return
        }

        let balanceFetchWrapper = createBalanceFetchWrapper()

        executeCancellable(
            wrapper: balanceFetchWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(balances):
                handleFetchedBalances(balances)
            case let .failure(error):
                completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        callStore.cancel()
    }
}
