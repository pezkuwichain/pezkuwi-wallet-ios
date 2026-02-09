import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS

final class AppMigrationDataBuilderTests: XCTestCase {
    func testBuildMigrationDataWithSettings() throws {
        // Given
        let settingsManager = InMemorySettingsManager()
        settingsManager.set(value: true, for: SettingsKey.biometryEnabled.rawValue)
        settingsManager.set(value: "USD", for: SettingsKey.selectedCurrency.rawValue)
        settingsManager.set(value: true, for: SettingsKey.hidesZeroBalances.rawValue)

        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsExporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: walletSecretsExporter
        )

        // When
        let wrapper = builder.buildWrapper()
        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let migrationData = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(migrationData.version, "1.0")
        XCTAssertEqual(migrationData.settings[SettingsKey.biometryEnabled.rawValue], .bool(true))
        XCTAssertEqual(migrationData.settings[SettingsKey.selectedCurrency.rawValue], .string("USD"))
        XCTAssertEqual(migrationData.settings[SettingsKey.hidesZeroBalances.rawValue], .bool(true))
        XCTAssertTrue(migrationData.wallets.publicInfo.isEmpty)
        XCTAssertTrue(migrationData.wallets.privateInfo.isEmpty)
    }

    func testBuildMigrationDataWithMnemonicWallet() throws {
        // Given
        let keystore = MockKeychain()
        let settingsManager = InMemorySettingsManager()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
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

        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsExporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: walletSecretsExporter
        )

        // When
        let wrapper = builder.buildWrapper()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let migrationData = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(migrationData.wallets.publicInfo.count, 1)
        XCTAssertEqual(migrationData.wallets.privateInfo.count, 1)

        guard let publicInfo = migrationData.wallets.publicInfo.first else {
            XCTFail("Expected public info")
            return
        }

        guard let privateInfo = migrationData.wallets.privateInfo.first else {
            XCTFail("Expected private info")
            return
        }

        XCTAssertEqual(publicInfo.walletId, privateInfo.walletId)
        XCTAssertNotNil(privateInfo.entropy)
        XCTAssertNotNil(privateInfo.substrate)
        XCTAssertNotNil(privateInfo.ethereum)
    }

    func testBuildMigrationDataWithMultipleWallets() throws {
        // Given
        let keystore = MockKeychain()
        let settingsManager = InMemorySettingsManager()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        // Create multiple wallets
        for i in 0 ..< 3 {
            try AccountCreationHelper.createMetaAccountFromMnemonic(
                cryptoType: .sr25519,
                name: "Wallet \(i)",
                keychain: keystore,
                settings: walletSettings
            )
        }

        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsExporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: walletSecretsExporter
        )

        // When
        let wrapper = builder.buildWrapper()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let migrationData = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(migrationData.wallets.publicInfo.count, 3)
        XCTAssertEqual(migrationData.wallets.privateInfo.count, 3)

        // Verify all wallets have matching public and private info
        let publicWalletIds = Set(migrationData.wallets.publicInfo.map(\.walletId))
        let privateWalletIds = Set(migrationData.wallets.privateInfo.map(\.walletId))
        XCTAssertEqual(publicWalletIds, privateWalletIds)
    }

    func testBuildMigrationDataWithWatchOnlyWallet() throws {
        // Given
        let keystore = MockKeychain()
        let settingsManager = InMemorySettingsManager()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
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

        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsExporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: walletSecretsExporter
        )

        // When
        let wrapper = builder.buildWrapper()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let migrationData = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(migrationData.wallets.publicInfo.count, 1)
    }

    func testBuildMigrationDataWithLedgerWallet() throws {
        // Given
        let keystore = MockKeychain()
        let settingsManager = InMemorySettingsManager()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
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

        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsExporter = AppMigrationWalletSecretsExporter(keychain: keystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: walletSecretsExporter
        )

        // When
        let wrapper = builder.buildWrapper()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let migrationData = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(migrationData.wallets.publicInfo.count, 1)
        XCTAssertEqual(migrationData.wallets.privateInfo.count, 1)

        guard let privateInfo = migrationData.wallets.privateInfo.first else {
            XCTFail("Expected private info for ledger wallet")
            return
        }

        // Ledger wallets have derivation paths in chain accounts, not entropy
        XCTAssertNil(privateInfo.entropy)
        XCTAssertFalse(privateInfo.chainAccounts.isEmpty)
    }

    func testMigrationDataSerialization() throws {
        // Given
        let settings: [String: CodableValue] = [
            "boolKey": .bool(true),
            "intKey": .int(42),
            "doubleKey": .double(3.14),
            "stringKey": .string("test"),
            "dataKey": .data(Data([0x01, 0x02, 0x03])),
            "nullKey": .null
        ]

        let migrationData = AppMigrationData(
            version: "1.0",
            migratedAt: 1_234_567_890,
            settings: settings,
            wallets: WalletsData(publicInfo: [], privateInfo: [])
        )

        // When
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(migrationData)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppMigrationData.self, from: encoded)

        // Then
        XCTAssertEqual(migrationData, decoded)
    }
}
