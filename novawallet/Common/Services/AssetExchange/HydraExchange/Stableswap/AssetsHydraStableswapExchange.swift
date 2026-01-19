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

    private func checkPairTradability(
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        tradabilities: [HydraStableswap.TradabilityPairKey: HydraStableswap.Tradability]
    ) -> Bool {
        let tradabilityKey = HydraStableswap.TradabilityPairKey(
            assetIn: assetIn,
            assetOut: assetOut
        )

        return if let pairTradability = tradabilities[tradabilityKey] {
            pairTradability.canBuy() && pairTradability.canSell()
        } else {
            true
        }
    }
}

extension AssetsHydraStableswapExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOpertion = host.runtimeService.fetchCoderFactoryOperation()
        let tradabilityWrapper = tradabilityFactory.fetchTradabilities()
        let allPoolsWrapper = swapFactory.fetchRemotePools()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let tradabilities = try tradabilityWrapper.targetOperation.extractNoCancellableResultData()
            let allPools = try allPoolsWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOpertion.extractNoCancellableResultData()

            let allRemoteAssets = Set(allPools.flatMap(\.value) + allPools.keys)

            self.logger.debug("Started processing edges")

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: allRemoteAssets,
                chain: self.host.chain,
                codingFactory: codingFactory
            )

            self.logger.debug("Complete processing edges \(remoteLocalMapping.count)")

            return allPools.flatMap { keyValue in
                let remotePoolAsset = keyValue.key
                let remotePoolAssets = Set(keyValue.value + [remotePoolAsset])

                return remotePoolAssets.flatMap { remoteAssetIn in
                    guard let localAssetIn = remoteLocalMapping[remoteAssetIn] else {
                        self.logger.warning("Skipped remote in \(remoteAssetIn) as no mapping found")
                        return [AnyAssetExchangeEdge]()
                    }

                    let otherAssets = remotePoolAssets.subtracting([remoteAssetIn])

                    return otherAssets.compactMap { remoteAssetOut in
                        guard let localAssetOut = remoteLocalMapping[remoteAssetOut] else {
                            self.logger.warning("Skipped remote out \(remoteAssetOut) as no mapping found")
                            return nil
                        }

                        guard self.checkPairTradability(
                            assetIn: remoteAssetIn,
                            assetOut: remoteAssetOut,
                            tradabilities: tradabilities
                        ) else {
                            self.logger.warning("Skipped remote out \(remoteAssetOut) as tradability check failed")
                            return nil
                        }

                        let edge = HydraStableswapExchangeEdge(
                            origin: localAssetIn,
                            destination: localAssetOut,
                            remoteSwapPair: .init(assetIn: remoteAssetIn, assetOut: remoteAssetOut),
                            poolAsset: remotePoolAsset,
                            host: self.host,
                            quoteFactory: self.quoteFactory
                        )

                        return AnyAssetExchangeEdge(edge)
                    }
                }
            }
        }

        mappingOperation.addDependency(codingFactoryOpertion)
        mappingOperation.addDependency(tradabilityWrapper.targetOperation)
        mappingOperation.addDependency(allPoolsWrapper.targetOperation)

        return allPoolsWrapper
            .insertingHead(operations: tradabilityWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOpertion])
            .insertingTail(operation: mappingOperation)
    }
}
