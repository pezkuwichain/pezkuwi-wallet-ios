import XCTest
@testable import novawallet

final class StakingDashboardBuilderDemotionTests: XCTestCase {
    var resultModel: StakingDashboardModel?

    func testDemotedChainRoutesToMoreOptions() {
        // given
        let alephZeroChain = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.alephZero,
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: true
        )

        let asset = alephZeroChain.assets.first!
        let chainAsset = ChainAsset(chain: alephZeroChain, asset: asset)

        let builder = StakingDashboardBuilder(
            callbackQueue: .main,
            resultClosure: { [weak self] result in
                self?.resultModel = result.model
            }
        )

        builder.applyAssets(models: [chainAsset])

        // when
        let model = resultModel

        // then
        XCTAssertNotNil(model, "Model should be generated")

        let moreChainIds = Set(model?.more.compactMap { item in
            item.chainAsset.chain.chainId
        } ?? [])

        let inactiveChainIds = Set(model?.inactive.compactMap { item in
            item.chainAsset.chain.chainId
        } ?? [])

        XCTAssertTrue(moreChainIds.contains(KnowChainId.alephZero),
                      "Aleph Zero should be in more options")
        XCTAssertFalse(inactiveChainIds.contains(KnowChainId.alephZero),
                       "Aleph Zero should NOT be in inactive section")
    }

    func testNonDemotedChainRoutesToInactiveSection() {
        // given
        let polkadotChain = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.polkadot,
            generatingAssets: 1,
            addressPrefix: 0,
            hasStaking: true
        )

        let asset = polkadotChain.assets.first!
        let chainAsset = ChainAsset(chain: polkadotChain, asset: asset)

        let builder = StakingDashboardBuilder(
            callbackQueue: .main,
            resultClosure: { [weak self] result in
                self?.resultModel = result.model
            }
        )

        builder.applyAssets(models: [chainAsset])

        // when
        let model = resultModel

        // then
        XCTAssertNotNil(model, "Model should be generated")

        let moreChainIds = Set(model?.more.compactMap { item in
            item.chainAsset.chain.chainId
        } ?? [])

        let inactiveChainIds = Set(model?.inactive.compactMap { item in
            item.chainAsset.chain.chainId
        } ?? [])

        XCTAssertTrue(inactiveChainIds.contains(KnowChainId.polkadot),
                      "Polkadot should be in inactive section")
        XCTAssertFalse(moreChainIds.contains(KnowChainId.polkadot),
                       "Polkadot should NOT be in more options")
    }

    func testDemotedChainWithActiveStakeStillAppearsInActive() {
        // given
        let alephZeroChain = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.alephZero,
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: true
        )

        let asset = alephZeroChain.assets.first!
        let chainAsset = ChainAsset(chain: alephZeroChain, asset: asset)

        // Create a mock wallet
        let account = AccountModel(
            address: "test_address",
            cryptoType: .sr25519,
            publicKey: Data(repeating: 0, count: 32),
            username: "Test User"
        )

        let chainAccountRequest = ChainAccountRequest(
            networkType: alephZeroChain.chainNetworkType,
            cryptoType: .sr25519
        )

        let walletModel = MetaAccountModel(
            metaId: "test_meta_id",
            name: "Test Wallet",
            substratePublicKey: Data(repeating: 0, count: 32),
            substrateAccountId: account.accountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [
                ChainAccount(
                    chainId: alephZeroChain.chainId,
                    accountId: account.accountId,
                    publicKey: account.publicKey,
                    cryptoType: account.cryptoType,
                    username: account.username
                )
            ],
            type: .substrate,
            googleBackupName: nil,
            isBackedUp: false
        )

        let dashboardItem = Multistaking.DashboardItem(
            stakingOption: .init(
                walletId: walletModel.metaId,
                option: .init(
                    chainAssetId: chainAsset.chainAssetId,
                    type: .relaychain
                )
            ),
            onchainState: .bonded,
            hasAssignedStake: true,
            stake: BigUInt(1000000000000),
            totalRewards: nil,
            maxApy: nil
        )

        let builder = StakingDashboardBuilder(
            callbackQueue: .main,
            resultClosure: { [weak self] result in
                self?.resultModel = result.model
            }
        )

        builder.applyWallet(model: walletModel)
        builder.applyAssets(models: [chainAsset])
        builder.applyDashboardItem(
            changes: [
                .insert(dashboardItem)
            ]
        )

        // when
        let model = resultModel

        // then
        XCTAssertNotNil(model, "Model should be generated")

        let activeChainIds = Set(model?.active.compactMap { item in
            item.chainAsset.chain.chainId
        } ?? [])

        let moreChainIds = Set(model?.more.compactMap { item in
            item.chainAsset.chain.chainId
        } ?? [])

        XCTAssertTrue(activeChainIds.contains(KnowChainId.alephZero),
                      "Aleph Zero with active stake should be in active section")
        XCTAssertFalse(moreChainIds.contains(KnowChainId.alephZero),
                       "Aleph Zero with active stake should NOT be in more options")
    }
}
