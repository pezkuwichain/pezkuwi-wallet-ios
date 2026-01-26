import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraStableswapTradabilityFactory {
    private let requestFactory: StorageRequestFactoryProtocol
    private let runtimeService: RuntimeProviderProtocol
    private let connection: JSONRPCEngine

    init(
        requestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine
    ) {
        self.requestFactory = requestFactory
        self.runtimeService = runtimeService
        self.connection = connection
    }
}

extension HydraStableswapTradabilityFactory {
    func fetchTradabilities() -> CompoundOperationWrapper<
        [HydraStableswap.TradabilityPairKey: HydraStableswap.Tradability]
    > {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[HydraStableswap.TradabilityPairKey: HydraStableswap.Tradability]>
        wrapper = requestFactory.queryByPrefix(
            engine: connection,
            request: UnkeyedRemoteStorageRequest(storagePath: HydraStableswap.tradability),
            storagePath: HydraStableswap.tradability,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        return wrapper.insertingHead(operations: [codingFactoryOperation])
    }
}
