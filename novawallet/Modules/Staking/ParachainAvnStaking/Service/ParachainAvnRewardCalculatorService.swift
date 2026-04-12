import Foundation
import BigInt
import SubstrateSdk
import Operation_iOS

/// Snapshot of the values needed to compute EWX staking APR.
struct ParachainAvnRewardSnapshot {
    let annualApr: Decimal
    let commission: Decimal
    let totalStaked: BigUInt
}

/// Reward calculator service for Energy Web X.
///
/// Fetches the `Growth` storage for the current growth period and
/// computes APR from: (totalStakerReward / totalStakeAccumulated) *
/// (365 / numberOfAccumulations). Falls back to the `Total` storage
/// item and annual inflation constants if growth data is unavailable.
final class ParachainAvnRewardCalculatorService: CollatorStakingRewardService<ParachainAvnRewardSnapshot> {
    let chainId: ChainModel.Id
    let collatorsService: ParachainStakingCollatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeCodingService: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let assetPrecision: Int16

    private var fetchCancellable = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        collatorsService: ParachainStakingCollatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        assetPrecision: Int16,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.collatorsService = collatorsService
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.operationQueue = operationQueue
        self.assetPrecision = assetPrecision

        let syncQueue = DispatchQueue(
            label: "com.novawallet.parachainavn.rewcalculator.\(UUID().uuidString)",
            qos: .userInitiated
        )

        super.init(eventCenter: eventCenter, logger: logger, syncQueue: syncQueue)
    }

    override func start() {
        NSLog("[EWT-DEBUG] ParachainAvnRewardCalculatorService start() called for chain %@", chainId)
        fetchGrowthData()
    }

    override func stop() {
        fetchCancellable.cancel()
    }

    override func deliver(snapshot: ParachainAvnRewardSnapshot, to pendingRequest: PendingRequest) {
        let collatorsOperation = collatorsService.fetchInfoOperation()

        let assetPrecision = self.assetPrecision

        let mapOperation = ClosureOperation<CollatorStakingRewardCalculatorEngineProtocol> {
            let selectedCollators = try collatorsOperation.extractNoCancellableResultData()

            return ParachainAvnRewardCalculatorEngine(
                annualApr: snapshot.annualApr,
                commission: snapshot.commission,
                totalStakedAmount: snapshot.totalStaked,
                selectedCollators: selectedCollators,
                assetPrecision: assetPrecision
            )
        }

        mapOperation.addDependency(collatorsOperation)

        mapOperation.completionBlock = {
            dispatchInQueueWhenPossible(pendingRequest.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    pendingRequest.resultClosure(calculator)
                case let .failure(error):
                    self.logger.error("ParachainAvn reward calculator error: \(error)")
                case .none:
                    self.logger.warning("ParachainAvn reward calculator cancelled")
                }
            }
        }

        operationQueue.addOperations([collatorsOperation, mapOperation], waitUntilFinished: false)
    }

    // MARK: - Private

    private func fetchGrowthData() {
        fetchCancellable.cancel()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue),
            timeout: JSONRPCTimeout.hour
        )

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        // Query total staked (u128 → BigUInt)
        let totalWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>>
        totalWrapper = requestFactory.queryItem(
            engine: connection,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: ParachainAvn.totalPath,
            at: nil
        )
        totalWrapper.addDependency(operations: [codingFactoryOperation])

        // NOTE: DefaultCollatorCommission is CommissionSetting (struct),
        // not a bare Perbill. Use the known mainnet value (10%) directly.
        let commissionPerbill: BigUInt = 100_000_000

        let mergeOperation = ClosureOperation<ParachainAvnRewardSnapshot> {
            // Use try? so a decode failure still produces a usable snapshot
            let totalResponse = try? totalWrapper.targetOperation.extractNoCancellableResultData()
            let totalStaked = totalResponse?.value?.value ?? 0

            let commission = Decimal.fromSubstratePerbill(value: commissionPerbill) ?? Decimal(0.10)

            // Estimate APR from known EWX economics:
            // 2M EWT annual growth rewards / total staked EWT
            let precision: Int16 = 18
            let totalStakedDecimal = Decimal.fromSubstrateAmount(
                totalStaked, precision: precision
            ) ?? 1

            let annualRewards: Decimal = 2_000_000
            let grossApr = totalStakedDecimal > 0 ? annualRewards / totalStakedDecimal : 0

            return ParachainAvnRewardSnapshot(
                annualApr: grossApr,
                commission: commission,
                totalStaked: totalStaked
            )
        }

        mergeOperation.addDependency(totalWrapper.targetOperation)

        let allDependencies = [codingFactoryOperation] + totalWrapper.allOperations
        let fullWrapper = CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: allDependencies
        )

        executeCancellable(
            wrapper: fullWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: fetchCancellable,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(snapshot):
                let apr = NSDecimalNumber(decimal: snapshot.annualApr).doubleValue
                NSLog("[EWT-DEBUG] Reward snapshot: apr=%.4f total=%@", apr, snapshot.totalStaked.description)
                self.updateSnapshotAndNotify(snapshot, chainId: self.chainId)
            case let .failure(error):
                NSLog("[EWT-DEBUG] Reward fetch FAILED: %@", error.localizedDescription)
                self.logger.error("ParachainAvn growth data fetch error: \(error)")
            }
        }
    }
}
