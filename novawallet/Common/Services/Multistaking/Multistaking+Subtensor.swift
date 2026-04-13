import Foundation
import BigInt

extension Multistaking {
    /// On-chain stake snapshot for Bittensor/TAO: the sum of all root (netuid=0)
    /// alpha positions, which are 1:1 TAO-denominated.
    struct SubtensorStakingState: Equatable {
        let totalStake: BigUInt
    }

    /// Partial dashboard item persisted by SubtensorMultistakingUpdateService.
    struct DashboardItemSubtensorPart: Equatable {
        let stakingOption: OptionWithWallet
        let state: SubtensorStakingState
    }
}
