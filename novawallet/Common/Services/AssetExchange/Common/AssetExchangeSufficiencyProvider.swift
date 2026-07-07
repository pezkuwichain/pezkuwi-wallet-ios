import Foundation

protocol AssetExchangeSufficiencyProviding {
    func isSufficient(asset: AssetModel) -> Bool
}

final class AssetExchangeSufficiencyProvider: AssetExchangeSufficiencyProviding {
    func isSufficient(asset: AssetModel) -> Bool {
        switch AssetType(rawType: asset.type) {
        case .none, .orml, .ormlHydrationEvm, .equilibrium, .evmAsset, .evmNative, .tronNative, .trc20:
            return true
        case .statemine:
            return asset.typeExtras?.isSufficient?.boolValue ?? false
        }
    }
}
