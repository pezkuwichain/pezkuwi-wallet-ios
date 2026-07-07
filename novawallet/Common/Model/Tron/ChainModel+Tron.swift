import Foundation

// Mirrors `Common/Model/Evm/ChainModel+Evm.swift`'s thin, purely-predicate style: these are
// model-layer helpers only, deliberately NOT wired into `CustomAssetMapper`/`AssetType`'s
// substrate-extrinsic fee-estimation and DEX-swap dispatch machinery (see the `.tronNative`/
// `.trc20` cases added there, which are unreachable dead branches for Tron since Tron chains have
// `noSubstrateRuntime` and never enter that pipeline). Tron balance fetching is a standalone
// TronGrid REST poller (see `Common/Network/TronGrid/`), not a `WalletRemoteSubscription`
// participant, so these helpers exist for that poller and for UI display code to use directly.
extension AssetModel {
    var isTronNative: Bool {
        type == AssetType.tronNative.rawValue
    }

    var isTronAsset: Bool {
        type == AssetType.trc20.rawValue
    }

    var isAnyTron: Bool {
        isTronNative || isTronAsset
    }

    // Same underlying `typeExtras.contractAddress` JSON field as `AssetModel.evmContractAddress`
    // (see `AssetTypeExtras.swift`) - reused as-is (chain-family-agnostic lookup), just named for
    // clarity at Tron call sites.
    var trc20ContractAddress: AccountAddress? {
        guard isTronAsset else {
            return nil
        }

        return typeExtras?.evmContractAddress
    }
}

extension ChainModel {
    var allTronAssets: [AssetModel] {
        assets.filter { $0.isAnyTron }
    }

    var hasTronAsset: Bool {
        assets.contains { $0.isAnyTron }
    }
}
