import Foundation
import BigInt
import SubstrateSdk

/// Thin helper that builds SubstrateSdk `RuntimeCall` values for Bittensor's
/// SubtensorModule staking extrinsics. Wraps slippage-adjusted limit price
/// computation so callers don't duplicate the math.
///
/// The v1 path always uses the limit variants (`add_stake_limit` /
/// `remove_stake_limit`) even on the root subnet where there is no AMM,
/// for belt-and-suspenders safety and to keep call shapes consistent
/// when v2 subnet staking is added.
enum SubtensorExtrinsicBuilder {
    /// Builds a `SubtensorModule.add_stake_limit(...)` call. For `netuid == 0`
    /// (root subnet), there is no AMM so the limit price is cosmetic — we
    /// still send a cushioned value so the call shape matches subnet paths.
    ///
    /// For subnet staking (`netuid != 0`), pass `spotPriceTaoPerAlpha` from
    /// the live AMM reserves (`SubnetTAO / SubnetAlphaIn`). The limit price
    /// is encoded as I96F32 (`value * 2^32`).
    static func buildAddStakeLimit(
        hotkey: AccountId,
        netuid: UInt16,
        amount: BigUInt,
        slippage: Double,
        spotPriceTaoPerAlpha: Double? = nil
    ) -> RuntimeCall<SubtensorPallet.AddStakeLimitCall> {
        let limitPrice = computeLimitPrice(
            netuid: netuid,
            slippage: slippage,
            isStake: true,
            spotPriceTaoPerAlpha: spotPriceTaoPerAlpha
        )

        let call = SubtensorPallet.AddStakeLimitCall(
            hotkey: hotkey,
            netuid: netuid,
            amountStaked: amount,
            limitPrice: limitPrice,
            allowPartial: false // TODO(v2 subnet): expose partial-fill toggle when subnet slippage becomes user-adjustable
        )

        return call.runtimeCall()
    }

    /// Builds a `SubtensorModule.remove_stake_limit(...)` call. Used for
    /// partial or full unstake. Instant execution — Bittensor has no
    /// unbonding period.
    static func buildRemoveStakeLimit(
        hotkey: AccountId,
        netuid: UInt16,
        amount: BigUInt,
        slippage: Double,
        spotPriceTaoPerAlpha: Double? = nil
    ) -> RuntimeCall<SubtensorPallet.RemoveStakeLimitCall> {
        let limitPrice = computeLimitPrice(
            netuid: netuid,
            slippage: slippage,
            isStake: false,
            spotPriceTaoPerAlpha: spotPriceTaoPerAlpha
        )

        let call = SubtensorPallet.RemoveStakeLimitCall(
            hotkey: hotkey,
            netuid: netuid,
            amountUnstaked: amount,
            limitPrice: limitPrice,
            allowPartial: false // TODO(v2 subnet): expose partial-fill toggle when subnet slippage becomes user-adjustable
        )

        return call.runtimeCall()
    }

    /// Builds a `SubtensorModule.move_stake(...)` call. Used for
    /// "change validator" — single-extrinsic move instead of unstake+restake.
    /// For v1 root-only staking, both netuids are 0.
    static func buildMoveStake(
        originHotkey: AccountId,
        destinationHotkey: AccountId,
        originNetuid: UInt16,
        destinationNetuid: UInt16,
        amount: BigUInt
    ) -> RuntimeCall<SubtensorPallet.MoveStakeCall> {
        let call = SubtensorPallet.MoveStakeCall(
            originHotkey: originHotkey,
            destinationHotkey: destinationHotkey,
            originNetuid: originNetuid,
            destinationNetuid: destinationNetuid,
            alphaAmount: amount
        )

        return call.runtimeCall()
    }

    /// Computes the slippage-cushioned limit price for `addStakeLimit` /
    /// `removeStakeLimit`.
    ///
    /// **Root (netuid=0):** alpha==TAO at 1:1. Baseline is 1 TAO =
    /// 1_000_000_000 RAO. The limit_price is in RAO (cosmetic, no AMM).
    ///
    /// **Subnets (netuid!=0):** The limit_price is encoded as **I96F32**
    /// fixed-point: `raw_bits = price_tao_per_alpha * 2^32`. The spot
    /// price is queried from `SubnetTAO / SubnetAlphaIn` and passed in
    /// via `spotPriceTaoPerAlpha`.
    ///
    /// Stake cushions upward (max price willing to pay); unstake cushions
    /// downward (min price willing to accept).
    private static func computeLimitPrice(
        netuid: UInt16,
        slippage: Double,
        isStake: Bool,
        spotPriceTaoPerAlpha: Double? = nil
    ) -> BigUInt {
        if netuid == SubtensorStakingConstants.rootNetuid {
            // Root: no AMM, use RAO-denominated 1:1 baseline
            let slippageDecimal = Decimal(slippage)
            let multiplier: Decimal = isStake ? (1 + slippageDecimal) : (1 - slippageDecimal)
            let baseline = Decimal(1_000_000_000)
            let product = baseline * multiplier

            let rounded: Decimal = {
                var mutableProduct = product
                var result = Decimal()
                NSDecimalRound(&result, &mutableProduct, 0, isStake ? .up : .down)
                return result
            }()

            return BigUInt((rounded as NSDecimalNumber).stringValue)
                ?? SubtensorStakingConstants.rawPerTao
        }

        // Subnet: I96F32 encoding. price_raw = spot_price * (1 ± slippage) * 2^32
        let spot = spotPriceTaoPerAlpha ?? 0.001 // conservative fallback
        let adjustedPrice = isStake ? spot * (1 + slippage) : spot * (1 - slippage)
        let i96f32Bits = adjustedPrice * Double(UInt64(1) << 32)
        let rawBits = UInt64(max(1, i96f32Bits)) // floor to 1 minimum

        return BigUInt(rawBits)
    }
}
