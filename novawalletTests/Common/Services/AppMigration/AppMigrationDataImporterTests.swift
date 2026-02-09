import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS

final class AppMigrationDataImporterTests: XCTestCase {
    func testImportSettings() throws {
        // Given
        let settingsManager = InMemorySettingsManager()
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsImporter = AppMigrationWalletSecretsImporter(keychain: keystore)

        let importer = AppMigrationDataImporter(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: walletSecretsImporter
        )

        let settings: [String: CodableValue] = [
            SettingsKey.biometryEnabled.rawValue: .bool(true),
            SettingsKey.selectedCurrency.rawValue: .string("EUR"),
            SettingsKey.hidesZeroBalances.rawValue: .bool(true)
        ]

        let migrationData = AppMigrationData(
            version: "1.0",
            migratedAt: UInt64(Date().timeIntervalSince1970),
            settings: settings,
            wallets: WalletsData(publicInfo: [], privateInfo: [])
        )

        // When
        let wrapper = importer.importWrapper(migrationData: migrationData)
        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(settingsManager.bool(for: SettingsKey.biometryEnabled.rawValue), true)
        XCTAssertEqual(settingsManager.string(for: SettingsKey.selectedCurrency.rawValue), "EUR")
        XCTAssertEqual(settingsManager.bool(for: SettingsKey.hidesZeroBalances.rawValue), true)
    }

    func testImportSettingsWithAllTypes() throws {
        // Given
        let settingsManager = InMemorySettingsManager()
        let keystore = MockKeychain()
        let storageFacade = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let walletSecretsImporter = AppMigrationWalletSecretsImporter(keychain: keystore)

        let importer = AppMigrationDataImporter(
            settingsManager: settingsManager,
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: walletSecretsImporter
        )

        let testData = Data([0x01, 0x02, 0x03])

        let settings: [String: CodableValue] = [
            "boolKey": .bool(true),
            "intKey": .int(42),
            "doubleKey": .double(3.14),
            "stringKey": .string("test"),
            "dataKey": .data(testData),
            "nullKey": .null
        ]

        let migrationData = AppMigrationData(
            version: "1.0",
            migratedAt: UInt64(Date().timeIntervalSince1970),
            settings: settings,
            wallets: WalletsData(publicInfo: [], privateInfo: [])
        )

        // When
        let wrapper = importer.importWrapper(migrationData: migrationData)
        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try wrapper.targetOperation.extractNoCancellableResultData()

        // Then
        XCTAssertEqual(settingsManager.bool(for: "boolKey"), true)
        XCTAssertEqual(settingsManager.integer(for: "intKey"), 42)
        XCTAssertEqual(settingsManager.double(for: "doubleKey"), 3.14)
        XCTAssertEqual(settingsManager.string(for: "stringKey"), "test")
        XCTAssertEqual(settingsManager.data(for: "dataKey"), testData)
        XCTAssertNil(settingsManager.anyValue(for: "nullKey"))
    }

    func testImportMnemonicWallet() throws {
        // Given - Create source wallet
        let sourceKeystore = MockKeychain()
        let sourceStorageFacade = UserDataStorageTestFacade()
        let sourceOperationQueue = OperationQueue()

        let sourceWalletSettings = SelectedWalletSettings(
            storageFacade: sourceStorageFacade,
            operationQueue: sourceOperationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: sourceKeystore,
            settings: sourceWalletSettings
        )

        guard let sourceWallet = sourceWalletSettings.value else {
            XCTFail("Source wallet should exist")
            return
        }

        // Build migration data from source
        let sourceAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: sourceStorageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: sourceAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: exporter
        )

        let buildWrapper = builder.buildWrapper()
        sourceOperationQueue.addOperations(buildWrapper.allOperations, waitUntilFinished: true)

        let migrationData = try buildWrapper.targetOperation.extractNoCancellableResultData()

        // Given - Prepare target
        let targetKeystore = MockKeychain()
        let targetStorageFacade = UserDataStorageTestFacade()
        let targetAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: targetStorageFacade)
        let walletSecretsImporter = AppMigrationWalletSecretsImporter(keychain: targetKeystore)

        let importer = AppMigrationDataImporter(
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: targetAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: walletSecretsImporter
        )

        // When
        let importWrapper = importer.importWrapper(migrationData: migrationData)
        let targetOperationQueue = OperationQueue()
        targetOperationQueue.addOperations(importWrapper.allOperations, waitUntilFinished: true)

        _ = try importWrapper.targetOperation.extractNoCancellableResultData()

        // Then - Verify wallet was imported
        let walletRepository = targetAccountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchWrapper = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        targetOperationQueue.addOperations([fetchWrapper], waitUntilFinished: true)

        let importedWallets = try fetchWrapper.extractNoCancellableResultData()

        XCTAssertEqual(importedWallets.count, 1)

        guard let importedWallet = importedWallets.first else {
            XCTFail("Expected imported wallet")
            return
        }

        XCTAssertEqual(importedWallet.metaId, sourceWallet.metaId)
        XCTAssertEqual(importedWallet.name, sourceWallet.name)

        // Verify secrets were imported
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(importedWallet.metaId)
        XCTAssertTrue(try targetKeystore.checkKey(for: entropyTag))

        let substrateSecretTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(importedWallet.metaId)
        XCTAssertTrue(try targetKeystore.checkKey(for: substrateSecretTag))

        let ethereumSecretTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(importedWallet.metaId)
        XCTAssertTrue(try targetKeystore.checkKey(for: ethereumSecretTag))
    }

    func testImportMultipleWallets() throws {
        // Given - Create source wallets
        let sourceKeystore = MockKeychain()
        let sourceStorageFacade = UserDataStorageTestFacade()
        let sourceOperationQueue = OperationQueue()

        let sourceWalletSettings = SelectedWalletSettings(
            storageFacade: sourceStorageFacade,
            operationQueue: sourceOperationQueue
        )

        var sourceWalletIds: Set<String> = []

        for i in 0 ..< 3 {
            try AccountCreationHelper.createMetaAccountFromMnemonic(
                cryptoType: .sr25519,
                name: "Wallet \(i)",
                keychain: sourceKeystore,
                settings: sourceWalletSettings
            )

            if let wallet = sourceWalletSettings.value {
                sourceWalletIds.insert(wallet.metaId)
            }
        }

        // Build migration data from source
        let sourceAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: sourceStorageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: sourceAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: exporter
        )

        let buildWrapper = builder.buildWrapper()
        sourceOperationQueue.addOperations(buildWrapper.allOperations, waitUntilFinished: true)

        let migrationData = try buildWrapper.targetOperation.extractNoCancellableResultData()

        // Given - Prepare target
        let targetKeystore = MockKeychain()
        let targetStorageFacade = UserDataStorageTestFacade()
        let targetAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: targetStorageFacade)
        let walletSecretsImporter = AppMigrationWalletSecretsImporter(keychain: targetKeystore)

        let importer = AppMigrationDataImporter(
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: targetAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: walletSecretsImporter
        )

        // When
        let importWrapper = importer.importWrapper(migrationData: migrationData)
        let targetOperationQueue = OperationQueue()
        targetOperationQueue.addOperations(importWrapper.allOperations, waitUntilFinished: true)

        _ = try importWrapper.targetOperation.extractNoCancellableResultData()

        // Then - Verify all wallets were imported
        let walletRepository = targetAccountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchWrapper = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        targetOperationQueue.addOperations([fetchWrapper], waitUntilFinished: true)

        let importedWallets = try fetchWrapper.extractNoCancellableResultData()

        XCTAssertEqual(importedWallets.count, 3)

        let importedWalletIds = Set(importedWallets.map(\.metaId))
        XCTAssertEqual(importedWalletIds, sourceWalletIds)
    }

    func testFullMigrationRoundTrip() throws {
        // Given - Create source environment with settings and wallets
        let sourceKeystore = MockKeychain()
        let sourceSettingsManager = InMemorySettingsManager()
        sourceSettingsManager.set(value: true, for: SettingsKey.biometryEnabled.rawValue)
        sourceSettingsManager.set(value: "GBP", for: SettingsKey.selectedCurrency.rawValue)

        let sourceStorageFacade = UserDataStorageTestFacade()
        let sourceOperationQueue = OperationQueue()

        let sourceWalletSettings = SelectedWalletSettings(
            storageFacade: sourceStorageFacade,
            operationQueue: sourceOperationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            name: "Main Wallet",
            derivationPath: "//test",
            keychain: sourceKeystore,
            settings: sourceWalletSettings
        )

        guard let sourceWallet = sourceWalletSettings.value else {
            XCTFail("Source wallet should exist")
            return
        }

        // Build migration data
        let sourceAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: sourceStorageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: sourceSettingsManager,
            walletRepositoryFactory: sourceAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: exporter
        )

        let buildWrapper = builder.buildWrapper()
        sourceOperationQueue.addOperations(buildWrapper.allOperations, waitUntilFinished: true)

        let migrationData = try buildWrapper.targetOperation.extractNoCancellableResultData()

        // Serialize and deserialize (simulating transfer)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(migrationData)

        let decoder = JSONDecoder()
        let decodedMigrationData = try decoder.decode(AppMigrationData.self, from: jsonData)

        // Import into target environment
        let targetKeystore = MockKeychain()
        let targetSettingsManager = InMemorySettingsManager()
        let targetStorageFacade = UserDataStorageTestFacade()
        let targetAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: targetStorageFacade)
        let walletSecretsImporter = AppMigrationWalletSecretsImporter(keychain: targetKeystore)

        let importer = AppMigrationDataImporter(
            settingsManager: targetSettingsManager,
            walletRepositoryFactory: targetAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: walletSecretsImporter
        )

        let importWrapper = importer.importWrapper(migrationData: decodedMigrationData)
        let targetOperationQueue = OperationQueue()
        targetOperationQueue.addOperations(importWrapper.allOperations, waitUntilFinished: true)

        _ = try importWrapper.targetOperation.extractNoCancellableResultData()

        // Verify settings
        XCTAssertEqual(targetSettingsManager.bool(for: SettingsKey.biometryEnabled.rawValue), true)
        XCTAssertEqual(targetSettingsManager.string(for: SettingsKey.selectedCurrency.rawValue), "GBP")

        // Verify wallet
        let walletRepository = targetAccountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchWrapper = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        targetOperationQueue.addOperations([fetchWrapper], waitUntilFinished: true)

        let importedWallets = try fetchWrapper.extractNoCancellableResultData()

        XCTAssertEqual(importedWallets.count, 1)

        guard let importedWallet = importedWallets.first else {
            XCTFail("Expected imported wallet")
            return
        }

        XCTAssertEqual(importedWallet.metaId, sourceWallet.metaId)
        XCTAssertEqual(importedWallet.name, "Main Wallet")

        // Verify secrets match
        let derivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(importedWallet.metaId)
        let sourceDerivation = sourceKeystore.getRawStore()[derivationTag]
        let targetDerivation = targetKeystore.getRawStore()[derivationTag]
        XCTAssertEqual(sourceDerivation, targetDerivation)

        let entropyTag = KeystoreTagV2.entropyTagForMetaId(importedWallet.metaId)
        let sourceEntropy = sourceKeystore.getRawStore()[entropyTag]
        let targetEntropy = targetKeystore.getRawStore()[entropyTag]
        XCTAssertEqual(sourceEntropy, targetEntropy)
    }
}
