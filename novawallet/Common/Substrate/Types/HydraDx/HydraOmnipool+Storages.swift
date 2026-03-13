import Foundation

extension HydraOmnipool {
    static var hubAssetIdPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.moduleName, constantName: "HubAssetId")
    }

    static var assetsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.moduleName, itemName: "Assets")
    }

    static var slipFeePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.moduleName, itemName: "SlipFee")
    }
}
