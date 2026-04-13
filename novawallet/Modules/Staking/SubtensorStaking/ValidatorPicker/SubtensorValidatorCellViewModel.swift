import Foundation
import UIKit
import SubstrateSdk

/// Display model for a row in the Subtensor validator picker.
///
/// Carries everything needed to render a 2-line cell:
///   line 1: identicon + bold validator name (or short hotkey)  | commission %
///   line 2: short hotkey                                       | total stake
///
/// `netuid` and `subnetBadge` are deliberately threaded through even though
/// v1 only ever uses `SubtensorStakingConstants.rootNetuid`. The picker is
/// subnet-ready: a subnet variant can render `subnetBadge` (e.g. "Subnet 3")
/// and reuse the exact same cell type without structural changes.
struct SubtensorValidatorCellViewModel {
    /// 32-byte AccountId of the hotkey. Used as the row identifier when the
    /// caller needs to map a tap back to the underlying `SubtensorValidator`.
    let hotkey: AccountId

    /// Subnet id this row represents. v1 always sets this to `rootNetuid`.
    let netuid: UInt16

    /// Pre-rendered drawable identicon. Cell will call
    /// `iconView.bind(icon:)` so the bind path stays trivial. May be nil if
    /// generation failed (e.g. malformed AccountId in tests) — the cell
    /// should hide the icon view in that case.
    let identicon: DrawableIcon?

    /// Friendly delegate name from the bittensor-delegates registry. nil if
    /// the delegate is unknown — the cell falls back to a short hotkey in the
    /// title slot.
    let displayName: String?

    /// Short hotkey rendered in monospace, e.g. "5E2L...eZ5u". Always present
    /// even if `displayName` is set so address visibility is preserved.
    let shortHotkey: String

    /// Pre-formatted commission percent string, e.g. "18.00%".
    let commissionText: String

    /// Pre-formatted total stake string, e.g. "1.2M TAO" or "0 TAO". Pre-
    /// formatting upstream avoids the cell pulling in BalanceViewModelFactory.
    let totalStakeText: String

    /// Optional subnet label. nil for v1 root staking. Subnet variants would
    /// pass e.g. "Subnet 3" to render a small trailing badge.
    let subnetBadge: String?
}
