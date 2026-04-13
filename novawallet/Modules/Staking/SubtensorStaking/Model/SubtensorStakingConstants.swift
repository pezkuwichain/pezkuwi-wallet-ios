import Foundation
import BigInt

enum SubtensorStakingConstants {
    /// Root subnet id. v1 hardcodes this; v2 will carry user-selected netuid.
    static let rootNetuid: UInt16 = 0

    /// 1 TAO = 10^9 RAO. The base unit conversion for Bittensor.
    /// Used as the baseline price (in RAO) per 1 alpha on the root subnet,
    /// where alpha:TAO is effectively 1:1 (no AMM).
    static let rawPerTao: BigUInt = 1_000_000_000

    /// Default slippage cushion for addStakeLimit / removeStakeLimit calls.
    /// Root subnet has no AMM so this is cosmetic on netuid=0, but we pay
    /// the tiny cost of using the limit variant for belt-and-suspenders safety.
    /// v2 subnet staking will use this as a real user-adjustable parameter.
    static let defaultSlippage: Double = 0.005

    /// Cached URL for the opentensor/bittensor-delegates registry.
    /// Used by BittensorDelegatesClient for validator identity metadata.
    static let delegatesRegistryURL = URL(
        string: "https://raw.githubusercontent.com/opentensor/bittensor-delegates/main/public/delegates.json"
    )!

    /// Conservative TAO reserve kept in free balance for tx fees on later
    /// unstake / change-validator flows. In RAO (1 TAO = 10^9 RAO).
    static let gasFeeReserveRao: UInt64 = 750 // 0.00000075 TAO
}
