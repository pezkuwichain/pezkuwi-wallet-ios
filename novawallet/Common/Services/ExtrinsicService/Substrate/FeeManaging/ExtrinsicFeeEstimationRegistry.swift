import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedChainAssetId(ChainAssetId?)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainModel
    let estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol
    let feeInstallingWrapperFactory: ExtrinsicFeeInstallingFactoryProtocol

    init(
        chain: ChainModel,
        estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol,
        feeInstallingWrapperFactory: ExtrinsicFeeInstallingFactoryProtocol
    ) {
        self.chain = chain
        self.estimatingWrapperFactory = estimatingWrapperFactory
        self.feeInstallingWrapperFactory = feeInstallingWrapperFactory
    }
}

private extension ExtrinsicFeeEstimationRegistry {
    func createFeeEstimatingWrapper(
        for asset: AssetModel,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard !asset.isUtility else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        switch AssetType(rawType: asset.type) {
        // Tron chains have no substrate runtime and never build extrinsics, so this branch is
        // unreachable for `.tronNative`/`.trc20` in practice - grouped with `.none` (native
        // fallback) since that's the safe, side-effect-free default if it were ever reached.
        case .none, .tronNative, .trc20:
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .equilibrium, .evmNative, .evmAsset, .orml, .ormlHydrationEvm, .statemine:
            return estimatingWrapperFactory.createCustomFeeEstimatingWrapper(
                asset: asset,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }
    }
}

extension ExtrinsicFeeEstimationRegistry: ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetId?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard let chainAssetId else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        guard
            chain.chainId == chainAssetId.chainId,
            let asset = chain.asset(for: chainAssetId.assetId)
        else {
            return CompoundOperationWrapper.createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }

        return createFeeEstimatingWrapper(
            for: asset,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let targetAssetId = chainAssetId ?? chain.utilityChainAssetId()

        guard
            let targetAssetId,
            targetAssetId.chainId == chain.chainId,
            let asset = chain.chainAsset(for: targetAssetId.assetId)
        else {
            return .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(targetAssetId)
            )
        }

        return feeInstallingWrapperFactory.createFeeInstallerWrapper(
            chainAsset: asset,
            accountClosure: accountClosure
        )
    }
}
