import XCTest
import BigInt
@testable import novawallet

final class SubtensorExtrinsicBuilderTests: XCTestCase {
    private let rootNetuid = SubtensorStakingConstants.rootNetuid
    private let oneTaoInRao = SubtensorStakingConstants.rawPerTao
    private let defaultSlippage: Double = 0.005

    private var hotkeyA: AccountId { Data(repeating: 0xAA, count: 32) }
    private var hotkeyB: AccountId { Data(repeating: 0xBB, count: 32) }

    // MARK: - add_stake_limit

    func test_buildAddStakeLimit_onRoot_usesSubtensorModuleAndLimitVariant() throws {
        let call = SubtensorExtrinsicBuilder.buildAddStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: oneTaoInRao,
            slippage: defaultSlippage
        )

        XCTAssertEqual(call.moduleName, "SubtensorModule")
        XCTAssertEqual(call.callName, "add_stake_limit")
        XCTAssertEqual(call.args.hotkey, hotkeyA)
        XCTAssertEqual(call.args.netuid, 0)
        XCTAssertEqual(call.args.amountStaked, oneTaoInRao)
        XCTAssertFalse(call.args.allowPartial)
    }

    func test_buildAddStakeLimit_onRoot_limitPriceIsBaselineTimesOnePlusSlippage() throws {
        let call = SubtensorExtrinsicBuilder.buildAddStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: oneTaoInRao,
            slippage: defaultSlippage
        )

        // 1_000_000_000 * (1 + 0.005) = 1_005_000_000
        let expected: BigUInt = 1_005_000_000
        XCTAssertEqual(call.args.limitPrice, expected)
    }

    // MARK: - remove_stake_limit

    func test_buildRemoveStakeLimit_onRoot_usesSubtensorModuleAndLimitVariant() throws {
        let half: BigUInt = 500_000_000 // 0.5 TAO
        let call = SubtensorExtrinsicBuilder.buildRemoveStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: half,
            slippage: defaultSlippage
        )

        XCTAssertEqual(call.moduleName, "SubtensorModule")
        XCTAssertEqual(call.callName, "remove_stake_limit")
        XCTAssertEqual(call.args.hotkey, hotkeyA)
        XCTAssertEqual(call.args.netuid, 0)
        XCTAssertEqual(call.args.amountUnstaked, half)
        XCTAssertFalse(call.args.allowPartial)
    }

    func test_buildRemoveStakeLimit_onRoot_limitPriceIsBaselineTimesOneMinusSlippage() throws {
        let call = SubtensorExtrinsicBuilder.buildRemoveStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: oneTaoInRao,
            slippage: defaultSlippage
        )

        // 1_000_000_000 * (1 - 0.005) = 995_000_000
        let expected: BigUInt = 995_000_000
        XCTAssertEqual(call.args.limitPrice, expected)
    }

    // MARK: - additional slippage cases

    func test_buildAddStakeLimit_onRoot_withOnePercentSlippage_usesExpectedLimitPrice() throws {
        let call = SubtensorExtrinsicBuilder.buildAddStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: oneTaoInRao,
            slippage: 0.01
        )
        // 1_000_000_000 * (1 + 0.01) = 1_010_000_000
        XCTAssertEqual(call.args.limitPrice, 1_010_000_000)
    }

    func test_buildRemoveStakeLimit_onRoot_withOnePercentSlippage_usesExpectedLimitPrice() throws {
        let call = SubtensorExtrinsicBuilder.buildRemoveStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: oneTaoInRao,
            slippage: 0.01
        )
        // 1_000_000_000 * (1 - 0.01) = 990_000_000
        XCTAssertEqual(call.args.limitPrice, 990_000_000)
    }

    func test_buildAddStakeLimit_onRoot_withZeroSlippage_returnsBaseline() throws {
        let call = SubtensorExtrinsicBuilder.buildAddStakeLimit(
            hotkey: hotkeyA,
            netuid: rootNetuid,
            amount: oneTaoInRao,
            slippage: 0.0
        )
        // 1_000_000_000 * (1 + 0.0) = 1_000_000_000 exact
        XCTAssertEqual(call.args.limitPrice, oneTaoInRao)
    }

    // MARK: - move_stake

    func test_buildMoveStake_onRoot_usesMoveStakeWithMatchingNetuids() throws {
        let amount: BigUInt = 250_000_000 // 0.25 TAO
        let call = SubtensorExtrinsicBuilder.buildMoveStake(
            originHotkey: hotkeyA,
            destinationHotkey: hotkeyB,
            originNetuid: rootNetuid,
            destinationNetuid: rootNetuid,
            amount: amount
        )

        XCTAssertEqual(call.moduleName, "SubtensorModule")
        XCTAssertEqual(call.callName, "move_stake")
        XCTAssertEqual(call.args.originHotkey, hotkeyA)
        XCTAssertEqual(call.args.destinationHotkey, hotkeyB)
        XCTAssertEqual(call.args.originNetuid, 0)
        XCTAssertEqual(call.args.destinationNetuid, 0)
        XCTAssertEqual(call.args.alphaAmount, amount)
    }
}
