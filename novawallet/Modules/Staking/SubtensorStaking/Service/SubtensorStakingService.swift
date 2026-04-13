import Foundation
import BigInt

/// Top-level service that coordinates validator fetching and stake-position
/// queries for Bittensor TAO root-subnet staking.
///
/// v1 uses placeholder stake-position queries (returns empty). The real
/// storage wiring depends on the exact Bittensor storage item names for
/// (hotkey, coldkey, netuid) -> stake triple-key maps, which are an open
/// question in the design spec §13 and will be filled in during the
/// post-MVP integration pass.
final class SubtensorStakingService {
    private let validatorProvider: SubtensorValidatorProvider
    private let selectedColdkey: AccountId

    init(
        validatorProvider: SubtensorValidatorProvider,
        selectedColdkey: AccountId
    ) {
        self.validatorProvider = validatorProvider
        self.selectedColdkey = selectedColdkey
    }

    /// Returns active validators for the given netuid. v1 callers pass 0.
    func fetchActiveValidators(netuid: UInt16) async throws -> [SubtensorValidator] {
        try await validatorProvider.fetchValidators(netuid: netuid)
    }

    /// Returns the user's current stake positions on a given netuid.
    ///
    /// TODO(integration): query SubtensorModule storage for
    /// (hotkey, coldkey, netuid) -> stake mappings matching selectedColdkey.
    /// Exact storage item name is open — see design spec §13.
    func fetchUserStakePositions(netuid _: UInt16) async throws -> [SubtensorStakePosition] {
        // v1 stub returns empty. Interactor + View must handle empty-list
        // gracefully since a user-not-yet-staked state is the common case.
        []
    }

    /// Returns the runtime constant for minimum delegation amount.
    ///
    /// TODO(integration): query subtensorModule.NominatorMinRequiredStake
    /// via state_getStorage. Returns the live mainnet value for v1.
    func fetchMinDelegation() async throws -> BigUInt {
        10_000_000 // 0.01 TAO in RAO — verified against live chain 2026-04-13
    }
}
