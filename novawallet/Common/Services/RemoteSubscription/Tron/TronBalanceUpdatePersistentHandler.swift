import Foundation
import Operation_iOS
import BigInt

/// Mirrors `Common/Services/RemoteSubscription/Evm/EvmBalanceUpdatePersistentHandler.swift`'s
/// diff/save/delete shape almost exactly - the only real difference is that the caller already
/// has the raw `accountId` on hand (no `AccountAddress -> AccountId` conversion needed here, since
/// the Tron sync service already resolved the account via `MetaAccountModel.fetch(for:)`).
final class TronBalanceUpdatePersistentHandler {
    let repository: AnyDataProviderRepository<AssetBalance>
    let operationQueue: OperationQueue

    init(repository: AnyDataProviderRepository<AssetBalance>, operationQueue: OperationQueue) {
        self.repository = repository
        self.operationQueue = operationQueue
    }

    private func createSaveOperation(
        dependingOn localBalancesOperation: BaseOperation<[ChainAssetId: AssetBalance]>,
        balances: [ChainAssetId: BigUInt],
        accountId: AccountId
    ) -> BaseOperation<Void> {
        repository.saveOperation({
            let localBalancesDict = try localBalancesOperation.extractNoCancellableResultData()

            return balances.compactMap { keyValue in
                let chainAssetId = keyValue.key
                let newBalance = keyValue.value
                let oldBalance = localBalancesDict[chainAssetId]?.totalInPlank

                guard newBalance > 0, newBalance != oldBalance else {
                    return nil
                }

                return AssetBalance(
                    tronBalance: newBalance,
                    accountId: accountId,
                    chainAssetId: chainAssetId
                )
            }
        }, {
            let localBalancesDict = try localBalancesOperation.extractNoCancellableResultData()

            return balances.compactMap { keyValue in
                let chainAssetId = keyValue.key
                let newBalance = keyValue.value

                guard newBalance == 0, let oldBalance = localBalancesDict[chainAssetId] else {
                    return nil
                }

                return oldBalance.identifier
            }
        })
    }

    /// Returns the wrapper's result as the set of `ChainAssetId`s whose stored balance actually
    /// changed (added, updated, or removed), so the caller can fire one `AssetBalanceChanged`
    /// event per changed asset - narrower/more precise than the EVM handler's plain `Bool`, since
    /// a single Tron poll cycle can update multiple assets (TRX + TRC20) at once.
    func createSaveWrapper(
        balances: [ChainAssetId: BigUInt],
        accountId: AccountId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let localBalancesFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let localBalancesMapOperation = ClosureOperation<[ChainAssetId: AssetBalance]> {
            let localAssetBalances = try localBalancesFetchOperation.extractNoCancellableResultData()
            return localAssetBalances.reduce(into: [ChainAssetId: AssetBalance]()) {
                $0[$1.chainAssetId] = $1
            }
        }

        localBalancesMapOperation.addDependency(localBalancesFetchOperation)

        let saveOperation = createSaveOperation(
            dependingOn: localBalancesMapOperation,
            balances: balances,
            accountId: accountId
        )

        saveOperation.addDependency(localBalancesMapOperation)

        let changedIdsOperation = ClosureOperation<Set<ChainAssetId>> {
            try saveOperation.extractNoCancellableResultData()

            let oldAssetBalances = try localBalancesMapOperation.extractNoCancellableResultData()

            return balances.reduce(into: Set<ChainAssetId>()) { changed, keyValue in
                let oldBalance = oldAssetBalances[keyValue.key]?.totalInPlank ?? 0

                if oldBalance != keyValue.value {
                    changed.insert(keyValue.key)
                }
            }
        }

        changedIdsOperation.addDependency(saveOperation)
        changedIdsOperation.addDependency(localBalancesMapOperation)

        return CompoundOperationWrapper(
            targetOperation: changedIdsOperation,
            dependencies: [localBalancesFetchOperation, localBalancesMapOperation, saveOperation]
        )
    }
}
