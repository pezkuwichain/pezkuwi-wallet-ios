import Foundation
import Operation_iOS

final class AssetsHydraStableswapExchange {
    let swapFactory: HydraStableswapTokensFactory
    let quoteFactory: HydraStableswapQuoteFactory
    let tradabilityFactory: HydraStableswapTradabilityFactory
    let host: HydraExchangeHostProtocol
    let logger: LoggerProtocol

    init(
        host: HydraExchangeHostProtocol,
        swapFactory: HydraStableswapTokensFactory,
        quoteFactory: HydraStableswapQuoteFactory,
        tradabilityFactory: HydraStableswapTradabilityFactory,
        logger: LoggerProtocol
    ) {
        self.host = host
        self.swapFactory = swapFactory
        self.quoteFactory = quoteFactory
        self.tradabilityFactory = tradabilityFactory
        self.logger = logger
    }
}

// MARK: - Private

private extension AssetsHydraStableswapExchange {
    struct EdgeBuildingContext {
        let tradabilities: [HydraStableswap.TradabilityPairKey: HydraStableswap.Tradability]
        let remoteLocalMapping: [HydraDx.AssetId: ChainAssetId]
    }

    func checkAssetTradability(
        poolId: HydraDx.AssetId,
        assetId: HydraDx.AssetId,
        tradabilities: [HydraStableswap.TradabilityPairKey: HydraStableswap.Tradability],
        checkClosure: (HydraStableswap.Tradability) -> Bool
    ) -> Bool {
        let tradabilityKey = HydraStableswap.TradabilityPairKey(
            poolId: poolId,
            assetId: assetId
        )

        return if let assetTradability = tradabilities[tradabilityKey] {
            checkClosure(assetTradability)
        } else {
            true
        }
    }

    func buildEdge(
        from remoteAssetIn: HydraDx.AssetId,
        to remoteAssetOut: HydraDx.AssetId,
        poolAsset: HydraDx.AssetId,
        context: EdgeBuildingContext
    ) -> AnyAssetExchangeEdge? {
        guard let localAssetOut = context.remoteLocalMapping[remoteAssetOut] else {
            logger.warning("Skipped remote out \(remoteAssetOut) as no mapping found")
            return nil
        }

        guard checkAssetTradability(
            poolId: poolAsset,
            assetId: remoteAssetOut,
            tradabilities: context.tradabilities,
            checkClosure: { $0.canBuy() }
        ) else {
            logger.warning("Skipped remote asset \(remoteAssetOut) in pool \(poolAsset) as not buyable")
            return nil
        }

        guard let localAssetIn = context.remoteLocalMapping[remoteAssetIn] else {
            return nil
        }

        let edge = HydraStableswapExchangeEdge(
            origin: localAssetIn,
            destination: localAssetOut,
            remoteSwapPair: .init(assetIn: remoteAssetIn, assetOut: remoteAssetOut),
            poolAsset: poolAsset,
            host: host,
            quoteFactory: quoteFactory
        )

        return AnyAssetExchangeEdge(edge)
    }

    func buildEdges(
        for remoteAssetIn: HydraDx.AssetId,
        poolAsset: HydraDx.AssetId,
        poolAssets: Set<HydraDx.AssetId>,
        context: EdgeBuildingContext
    ) -> [AnyAssetExchangeEdge] {
        guard context.remoteLocalMapping[remoteAssetIn] != nil else {
            logger.warning("Skipped remote in \(remoteAssetIn) as no mapping found")
            return []
        }

        guard checkAssetTradability(
            poolId: poolAsset,
            assetId: remoteAssetIn,
            tradabilities: context.tradabilities,
            checkClosure: { $0.canSell() }
        ) else {
            logger.warning("Skipped remote asset \(remoteAssetIn) in pool \(poolAsset) as not sellable")
            return []
        }

        let otherAssets = poolAssets.subtracting([remoteAssetIn])

        return otherAssets.compactMap { remoteAssetOut in
            buildEdge(
                from: remoteAssetIn,
                to: remoteAssetOut,
                poolAsset: poolAsset,
                context: context
            )
        }
    }

    func buildAllEdges(
        from allPools: [HydraDx.AssetId: [HydraDx.AssetId]],
        context: EdgeBuildingContext
    ) -> [AnyAssetExchangeEdge] {
        allPools.flatMap { poolAsset, poolMembers in
            let poolAssets = Set(poolMembers + [poolAsset])

            return poolAssets.flatMap { remoteAssetIn in
                buildEdges(
                    for: remoteAssetIn,
                    poolAsset: poolAsset,
                    poolAssets: poolAssets,
                    context: context
                )
            }
        }
    }
}

// MARK: - AssetsExchangeProtocol

extension AssetsHydraStableswapExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()
        let tradabilityWrapper = tradabilityFactory.fetchTradabilities()
        let allPoolsWrapper = swapFactory.fetchRemotePools()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let tradabilities = try tradabilityWrapper.targetOperation.extractNoCancellableResultData()
            let allPools = try allPoolsWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let allRemoteAssets = Set(allPools.flatMap(\.value) + allPools.keys)

            self.logger.debug("Started processing edges")

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: allRemoteAssets,
                chain: self.host.chain,
                codingFactory: codingFactory
            )

            self.logger.debug("Complete processing edges \(remoteLocalMapping.count)")

            let context = EdgeBuildingContext(
                tradabilities: tradabilities,
                remoteLocalMapping: remoteLocalMapping
            )

            return self.buildAllEdges(from: allPools, context: context)
        }

        mappingOperation.addDependency(codingFactoryOperation)
        mappingOperation.addDependency(tradabilityWrapper.targetOperation)
        mappingOperation.addDependency(allPoolsWrapper.targetOperation)

        return allPoolsWrapper
            .insertingHead(operations: tradabilityWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }
}
