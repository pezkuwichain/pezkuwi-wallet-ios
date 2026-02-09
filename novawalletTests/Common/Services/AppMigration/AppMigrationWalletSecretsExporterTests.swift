import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS

final class AppMigrationWalletSecretsExporterTests: XCTestCase {
    func testExportSecretsFromMnemonicWallet() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        // Then
        XCTAssertEqual(privateInfoSet.count, 1)

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertEqual(privateInfo.walletId, wallet.metaId)
        XCTAssertNotNil(privateInfo.entropy)
        XCTAssertNotNil(privateInfo.substrate)
        XCTAssertNotNil(privateInfo.substrate?.keypair)
        XCTAssertNotNil(privateInfo.ethereum)
        XCTAssertNotNil(privateInfo.ethereum?.keypair)
    }

    func testExportSecretsFromMnemonicWalletWithDerivationPath() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let derivationPath = "//hard/soft///password"

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            derivationPath: derivationPath,
            keychain: keystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        // Then
        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertEqual(privateInfo.substrate?.derivationPath, derivationPath)
    }

    func testExportSecretsFromSeedWallet() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let seed = Data.random(of: 32)!.toHexString()

        try AccountCreationHelper.createMetaAccountFromSeed(
            seed,
            cryptoType: .sr25519,
            keychain: keystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        // Then
        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertEqual(privateInfo.walletId, wallet.metaId)
        // Seed wallets don't have entropy
        XCTAssertNil(privateInfo.entropy)
        XCTAssertNotNil(privateInfo.substrate?.seed)
        XCTAssertNotNil(privateInfo.substrate?.keypair)
    }

    func testExportSecretsFromWatchOnlyWalletReturnsEmpty() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let substrateAddress = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"

        try AccountCreationHelper.createWatchOnlyMetaAccount(
            from: substrateAddress,
            ethereumAddress: nil,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        // Then
        XCTAssertTrue(privateInfoSet.isEmpty)
    }

    func testExportSecretsFromLedgerWallet() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        guard let ledgerApp = SupportedLedgerApp.substrate().first else {
            XCTFail("No supported ledger app")
            return
        }

        try AccountCreationHelper.createSubstrateLedgerAccount(
            from: ledgerApp,
            keychain: keystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        // Then
        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertEqual(privateInfo.walletId, wallet.metaId)
        XCTAssertNil(privateInfo.entropy)
        XCTAssertNil(privateInfo.substrate)
        XCTAssertNil(privateInfo.ethereum)
        XCTAssertFalse(privateInfo.chainAccounts.isEmpty)

        // Verify chain account has derivation path
        guard let chainAccountSecrets = privateInfo.chainAccounts.first else {
            XCTFail("Expected chain account secrets")
            return
        }

        XCTAssertNotNil(chainAccountSecrets.derivationPath)
    }

    func testExportSecretsFromGenericLedgerWallet() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createGenericLedgerWallet(
            keychain: keystore,
            settings: walletSettings,
            includesEvm: true
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        // Then
        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertEqual(privateInfo.walletId, wallet.metaId)
        XCTAssertNil(privateInfo.entropy)
        XCTAssertNotNil(privateInfo.substrate)
        XCTAssertNotNil(privateInfo.substrate?.derivationPath)
        XCTAssertNil(privateInfo.substrate?.seed)
        XCTAssertNil(privateInfo.substrate?.keypair)
        XCTAssertNotNil(privateInfo.ethereum)
        XCTAssertNotNil(privateInfo.ethereum?.derivationPath)
    }

    func testExportSecretsFromMultipleWallets() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        var wallets: [MetaAccountModel] = []

        for i in 0 ..< 3 {
            try AccountCreationHelper.createMetaAccountFromMnemonic(
                cryptoType: .sr25519,
                name: "Wallet \(i)",
                keychain: keystore,
                settings: walletSettings
            )

            if let wallet = walletSettings.value {
                wallets.append(wallet)
            }
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: Set(wallets))

        // Then
        XCTAssertEqual(privateInfoSet.count, 3)

        let exportedWalletIds = Set(privateInfoSet.map(\.walletId))
        let originalWalletIds = Set(wallets.map(\.metaId))
        XCTAssertEqual(exportedWalletIds, originalWalletIds)
    }

    func testExportSecretsWithChainAccounts() throws {
        // Given
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Add chain account
        try AccountCreationHelper.addMnemonicChainAccount(
            to: wallet,
            chainId: KnowChainId.kusama,
            cryptoType: .sr25519,
            derivationPath: "//kusama",
            keychain: keystore,
            settings: walletSettings
        )

        guard let updatedWallet = walletSettings.value else {
            XCTFail("Updated wallet should exist")
            return
        }

        let exporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        // When
        let privateInfoSet = try exporter.exportSecrets(from: [updatedWallet])

        // Then
        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertFalse(privateInfo.chainAccounts.isEmpty)

        guard let chainAccountSecrets = privateInfo.chainAccounts.first else {
            XCTFail("Expected chain account secrets")
            return
        }

        XCTAssertNotNil(chainAccountSecrets.entropy)
        XCTAssertEqual(chainAccountSecrets.derivationPath, "//kusama")
        XCTAssertNotNil(chainAccountSecrets.keypair)
    }
}
