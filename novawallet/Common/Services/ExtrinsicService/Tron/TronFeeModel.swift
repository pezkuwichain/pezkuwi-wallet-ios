import Foundation
import BigInt

/// Mirrors `EvmFeeModel`'s role. Tron has no gas-price auction - the wallet only estimates how
/// much TRX the network's default burn-on-insufficient-resource behavior would consume:
/// `bandwidthFeeInSun` for the `NET` resource (relevant to every transfer) and
/// `energyFeeInSun` for the `ENERGY` resource (relevant to TRC20/smart-contract calls only, `0`
/// for a native TRX transfer).
struct TronFeeModel {
    let bandwidthFeeInSun: BigUInt
    let energyFeeInSun: BigUInt

    var fee: BigUInt {
        bandwidthFeeInSun + energyFeeInSun
    }
}
