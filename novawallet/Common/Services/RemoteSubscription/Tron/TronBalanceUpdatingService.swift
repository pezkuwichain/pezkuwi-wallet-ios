import Foundation
import Operation_iOS

/// Chain-list-driven lifecycle wrapper around `TronAccountBalanceSyncService`, mirroring
/// `EvmNativeBalanceUpdatingService`'s role (subclassing the same
/// `AssetBalanceBatchBaseUpdatingService` base for chain enable/disable and wallet-switch
/// handling) but managing a single REST-polling sync service per Tron chain instead of a
/// per-asset JSON-RPC subscription, since Tron has no JSON-RPC/WebSocket transport to subscribe
/// to (see `Common/Model/Tron/ChainModel+Tron.swift`).
final class TronBalanceUpdatingService: AssetBalanceBatchBaseUpdatingService {
    let operationFactoryFactory: (URL) -> TronGridOperationFactoryProtocol
    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol

    private var syncServices: [ChainModel.Id: TronAccountBalanceSyncService] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        operationFactoryFactory: @escaping (URL) -> TronGridOperationFactoryProtocol = { TronGridOperationFactory(baseUrl: $0) }
    ) {
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.operationFactoryFactory = operationFactoryFactory

        super.init(selectedAccount: selectedAccount, chainRegistry: chainRegistry, logger: logger)
    }

    private func createSyncService(
        for chain: ChainModel,
        accountId: AccountId,
        accountAddress: AccountAddress
    ) -> TronAccountBalanceSyncService? {
        guard let nodeUrlString = chain.nodes.first?.url, let nodeUrl = URL(string: nodeUrlString) else {
            logger.warning("No valid TronGrid node configured for chain \(chain.name)")
            return nil
        }

        let mapper = AssetBalanceMapper()
        let filter = NSPredicate.assetBalance(for: chain.chainId, accountId: accountId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let updateHandler = TronBalanceUpdatePersistentHandler(
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        return TronAccountBalanceSyncService(
            chainId: chain.chainId,
            accountId: accountId,
            accountAddress: accountAddress,
            assets: chain.allTronAssets.filter(\.enabled),
            operationFactory: operationFactoryFactory(nodeUrl),
            updateHandler: updateHandler,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    override func updateSubscription(for chain: ChainModel) {
        guard chain.isTronBased, chain.hasTronAsset, !chain.isDisabled else {
            removeSubscription(for: chain.chainId)
            return
        }

        guard
            let response = selectedMetaAccount.fetch(for: chain.accountRequest()),
            let accountAddress = response.toAddress() else {
            removeSubscription(for: chain.chainId)
            return
        }

        if let existingService = syncServices[chain.chainId] {
            guard existingService.accountId != response.accountId else {
                // already syncing the right account for this chain
                return
            }

            existingService.throttle()
        }

        guard let syncService = createSyncService(
            for: chain,
            accountId: response.accountId,
            accountAddress: accountAddress
        ) else {
            return
        }

        syncServices[chain.chainId] = syncService
        syncService.setup()

        // `AssetBalanceBatchBaseUpdatingService.removeAllSubscriptions()` (called from
        // `throttle()`/`update(selectedMetaAccount:)`) only tears down chains present in the base
        // class's own `subscribedChains` bookkeeping, which is only populated via
        // `setSubscriptions`/`getSubscriptions`. Without registering something here, a wallet
        // switch or app backgrounding would never call our `removeSubscription(for:)` override at
        // all, leaking a running poller for the previously-selected account. The `SubscriptionInfo`
        // content itself is unused by us (we track the real service in `syncServices`) - this call
        // exists purely to make the base class aware this chain has an active subscription to tear
        // down.
        if let nativeAssetId = chain.allTronAssets.first(where: \.enabled)?.assetId {
            let info = SubscriptionInfo(
                subscriptionId: UUID(),
                accountId: response.accountId,
                asset: chain.asset(for: nativeAssetId) ?? chain.allTronAssets[0]
            )
            setSubscriptions(for: chain.chainId, subscriptions: [nativeAssetId: info])
        }
    }

    override func removeSubscription(for chainId: ChainModel.Id) {
        clearSubscriptions(for: chainId)

        guard let service = syncServices[chainId] else {
            return
        }

        service.throttle()
        syncServices[chainId] = nil
    }
}
