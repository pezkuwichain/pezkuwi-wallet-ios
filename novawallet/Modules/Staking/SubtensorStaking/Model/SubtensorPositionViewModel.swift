import Foundation
import BigInt
import SubstrateSdk

/// Display model for a single user stake position row on the main staking screen.
struct SubtensorPositionViewModel {
    /// Raw hotkey bytes — used for routing (unstake / manage actions).
    let hotkey: AccountId

    /// Subnet identifier — 0 = root.
    let netuid: UInt16

    /// Polkadot-style identicon for the hotkey.
    let identicon: DrawableIcon?

    /// Primary display name: validator identity name if known, otherwise short hotkey.
    let nameText: String

    /// True when `nameText` is a short hotkey (no identity). Caller uses this
    /// to apply a monospace font.
    let nameIsAddress: Bool

    /// Short hotkey ("5E2L...eZ5u") shown as secondary line when an identity name exists.
    let shortHotkey: String?

    /// Human-readable network label: "Root", "SN1", "SN8" etc.
    let networkText: String

    /// Formatted stake amount, e.g. "0.0042 TAO" or "14,230.00 α".
    let amountText: String
}

// MARK: - Factory

extension SubtensorPositionViewModel {
    /// Builds a display view model from a resolved stake position.
    static func make(
        from position: SubtensorStakePosition,
        assetPrecision: Int16
    ) -> SubtensorPositionViewModel {
        let address = (try? position.hotkey.toAddressWithDefaultConversion()) ?? position.hotkey.toHex()
        let shortHk = shorten(address: address)
        let identicon = try? PolkadotIconGenerator().generateFromAccountId(position.hotkey)

        let hasName = position.validatorIdentity?.isEmpty == false
        let nameText = hasName ? position.validatorIdentity! : shortHk
        let secondaryHotkey: String? = hasName ? shortHk : nil

        let networkText = position.netuid == SubtensorStakingConstants.rootNetuid
            ? "Root"
            : "SN\(position.netuid)"

        let amountText = formatAmount(
            position.amount,
            precision: max(0, Int(assetPrecision)),
            isRoot: position.netuid == SubtensorStakingConstants.rootNetuid
        )

        return SubtensorPositionViewModel(
            hotkey: position.hotkey,
            netuid: position.netuid,
            identicon: identicon,
            nameText: nameText,
            nameIsAddress: !hasName,
            shortHotkey: secondaryHotkey,
            networkText: networkText,
            amountText: amountText
        )
    }

    private static func formatAmount(_ amount: BigUInt, precision: Int, isRoot: Bool) -> String {
        guard precision > 0 else { return "\(amount) \(isRoot ? "TAO" : "α")" }
        let divisor = BigUInt(10).power(precision)
        let whole = amount / divisor
        let fractional = amount % divisor

        let decimalsToShow = min(4, precision)
        let fracScale = BigUInt(10).power(precision - decimalsToShow)
        let fracPart = fractional / fracScale

        let fracStr = String(fracPart).leftPadded(toLength: decimalsToShow, with: "0")
        let symbol = isRoot ? "TAO" : "α"
        return "\(whole).\(fracStr) \(symbol)"
    }

    private static func shorten(address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

private extension String {
    func leftPadded(toLength length: Int, with pad: Character) -> String {
        guard count < length else { return self }
        return String(repeating: pad, count: length - count) + self
    }
}
