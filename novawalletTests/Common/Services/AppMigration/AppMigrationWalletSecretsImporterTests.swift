import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS

final class AppMigrationWalletSecretsImporterTests: XCTestCase {
    func testImportMnemonicWalletSecrets() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: sourceKeystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Export from source
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // When - Import to target
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: wallet, privateInfo: privateInfo)

        // Then - Validate keystore contents match
        let sourceRawStore = sourceKeystore.getRawStore()
        let targetRawStore = targetKeystore.getRawStore()

        // Check entropy
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        XCTAssertEqual(sourceRawStore[entropyTag], targetRawStore[entropyTag])

        // Check substrate secrets
        let substrateSeedTag = KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        XCTAssertEqual(sourceRawStore[substrateSeedTag], targetRawStore[substrateSeedTag])

        let substrateSecretKeyTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        XCTAssertEqual(sourceRawStore[substrateSecretKeyTag], targetRawStore[substrateSecretKeyTag])

        // Check ethereum secrets
        let ethereumSecretKeyTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        XCTAssertEqual(sourceRawStore[ethereumSecretKeyTag], targetRawStore[ethereumSecretKeyTag])
    }

    func testImportMnemonicWalletSecretsWithDerivationPath() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
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
            keychain: sourceKeystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Export from source
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // When - Import to target
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: wallet, privateInfo: privateInfo)

        // Then - Validate derivation path
        let derivationPathTag = KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)
        let importedDerivationPath = try targetKeystore.fetchKey(for: derivationPathTag)
        let importedDerivationPathString = String(data: importedDerivationPath, encoding: .utf8)

        XCTAssertEqual(importedDerivationPathString, derivationPath)
    }

    func testImportSeedWalletSecrets() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
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
            keychain: sourceKeystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Export from source
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // When - Import to target
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: wallet, privateInfo: privateInfo)

        // Then - Validate seed
        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        let sourceRawStore = sourceKeystore.getRawStore()
        let targetRawStore = targetKeystore.getRawStore()

        XCTAssertEqual(sourceRawStore[seedTag], targetRawStore[seedTag])
    }

    func testImportLedgerWalletSecrets() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
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
            keychain: sourceKeystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Export from source
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // When - Import to target
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: wallet, privateInfo: privateInfo)

        // Then - Validate chain account derivation paths
        guard let chainAccount = wallet.chainAccounts.first else {
            XCTFail("Expected chain account")
            return
        }

        let derivationPathTag = KeystoreTagV2.substrateDerivationTagForMetaId(
            wallet.metaId,
            accountId: chainAccount.accountId
        )

        let sourceRawStore = sourceKeystore.getRawStore()
        let targetRawStore = targetKeystore.getRawStore()

        XCTAssertEqual(sourceRawStore[derivationPathTag], targetRawStore[derivationPathTag])
    }

    func testImportGenericLedgerWalletSecrets() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createGenericLedgerWallet(
            keychain: sourceKeystore,
            settings: walletSettings,
            includesEvm: true
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Export from source
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // When - Import to target
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: wallet, privateInfo: privateInfo)

        // Then - Validate substrate derivation path
        let substrateDerivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)
        let sourceRawStore = sourceKeystore.getRawStore()
        let targetRawStore = targetKeystore.getRawStore()

        XCTAssertEqual(sourceRawStore[substrateDerivationTag], targetRawStore[substrateDerivationTag])

        // Validate ethereum derivation path
        let ethDerivationTag = KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId)
        XCTAssertEqual(sourceRawStore[ethDerivationTag], targetRawStore[ethDerivationTag])
    }

    func testImportWalletSecretsWithChainAccounts() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: sourceKeystore,
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
            keychain: sourceKeystore,
            settings: walletSettings
        )

        guard let updatedWallet = walletSettings.value else {
            XCTFail("Updated wallet should exist")
            return
        }

        // Export from source
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [updatedWallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // When - Import to target
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: updatedWallet, privateInfo: privateInfo)

        // Then - Validate chain account secrets
        guard let chainAccount = updatedWallet.chainAccounts.first else {
            XCTFail("Expected chain account")
            return
        }

        let entropyTag = KeystoreTagV2.entropyTagForMetaId(
            updatedWallet.metaId,
            accountId: chainAccount.accountId
        )

        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(
            updatedWallet.metaId,
            accountId: chainAccount.accountId
        )

        let secretKeyTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(
            updatedWallet.metaId,
            accountId: chainAccount.accountId
        )

        let derivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(
            updatedWallet.metaId,
            accountId: chainAccount.accountId
        )

        let sourceRawStore = sourceKeystore.getRawStore()
        let targetRawStore = targetKeystore.getRawStore()

        XCTAssertEqual(sourceRawStore[entropyTag], targetRawStore[entropyTag])
        XCTAssertEqual(sourceRawStore[seedTag], targetRawStore[seedTag])
        XCTAssertEqual(sourceRawStore[secretKeyTag], targetRawStore[secretKeyTag])
        XCTAssertEqual(sourceRawStore[derivationTag], targetRawStore[derivationTag])
    }

    func testRoundTripExportImportPreservesAllSecrets() throws {
        // Given
        let sourceKeystore = MockKeychain()
        let targetKeystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            derivationPath: "//test/path",
            keychain: sourceKeystore,
            settings: walletSettings
        )

        guard let wallet = walletSettings.value else {
            XCTFail("Wallet should exist")
            return
        }

        // Export
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)
        let privateInfoSet = try exporter.exportSecrets(from: [wallet])

        guard let privateInfo = privateInfoSet.first else {
            XCTFail("Expected private info")
            return
        }

        // Import
        let importer = AppMigrationWalletSecretsImporter(keychain: targetKeystore)
        try importer.importSecrets(for: wallet, privateInfo: privateInfo)

        // Then - All relevant keys should be copied
        let sourceStore = sourceKeystore.getRawStore()
        let targetStore = targetKeystore.getRawStore()

        // Get all keys related to this wallet from source
        let walletRelatedKeys = sourceStore.keys.filter { $0.contains(wallet.metaId) }

        for key in walletRelatedKeys {
            XCTAssertEqual(
                sourceStore[key],
                targetStore[key],
                "Key \(key) should match between source and target"
            )
        }
    }
}
