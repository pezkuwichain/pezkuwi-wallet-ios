import Foundation
import BigInt

/// Coordinates validator fetching and stake-position queries for TAO staking.
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

    /// Returns active validators for the given netuid. Pass 0 for root.
    func fetchActiveValidators(netuid: UInt16) async throws -> [SubtensorValidator] {
        try await validatorProvider.fetchValidators(netuid: netuid)
    }

    /// Returns the user's current stake positions across all hotkeys and netuids.
    /// Queries SubtensorModule.StakingHotkeys + Alpha + TotalHotkeyAlpha/Shares.
    func fetchUserStakePositions() async throws -> [SubtensorStakePosition] {
        let rawPositions = try await SubtensorPositionFetcher.fetchPositions(coldkey: selectedColdkey)
        guard !rawPositions.isEmpty else { return [] }

        // Best-effort: load validator identities for display names.
        let validators = (try? await validatorProvider.fetchValidators(netuid: SubtensorStakingConstants.rootNetuid)) ?? []
        let identityMap: [AccountId: String] = Dictionary(
            validators.compactMap { validator -> (AccountId, String)? in
                guard let name = validator.identity, !name.isEmpty else { return nil }
                return (validator.hotkey, name)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return rawPositions.map { raw in
            SubtensorStakePosition(
                coldkey: selectedColdkey,
                hotkey: raw.hotkey,
                netuid: raw.netuid,
                amount: raw.amount,
                validatorIdentity: identityMap[raw.hotkey]
            )
        }
    }

    /// Returns the runtime minimum delegation amount in RAO (0.01 TAO).
    func fetchMinDelegation() async throws -> BigUInt {
        10_000_000 // 0.01 TAO in RAO — verified against live chain 2026-04-13
    }
}
