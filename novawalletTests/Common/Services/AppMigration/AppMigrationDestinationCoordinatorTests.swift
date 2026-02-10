import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import Cuckoo

final class AppMigrationDestinationCoordinatorTests: XCTestCase {
    func testSetupAddsObserver() {
        // Given
        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let coordinator = createDestinationCoordinator(service: service)

        // When
        coordinator.setup()

        // Then - Verify observer was added
        XCTAssertNotNil(capturedObserver)
    }

    func testTeardownRemovesObserver() {
        // Given
        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?
        var observerRemoved = false

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).then { observer in
                if observer === capturedObserver {
                    observerRemoved = true
                }
            }
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()
        stub(mockDestination) { stub in
            when(stub.accept(with: any())).thenDoNothing()
        }

        let coordinator = createDestinationCoordinator(
            service: service,
            destination: mockDestination
        )

        coordinator.setup()
        coordinator.teardown()

        // Then
        XCTAssertTrue(observerRemoved)
    }

    func testHandleStartMessageSendsAcceptance() {
        // Given
        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()
        var sentAcceptMessage: AppMigrationMessage.Accepted?

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).then { message in
                sentAcceptMessage = message
            }
        }

        let coordinator = createDestinationCoordinator(
            service: service,
            destination: mockDestination
        )

        coordinator.setup()

        // When
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")
        capturedObserver?.didReceiveMigration(message: .start(startMessage))

        // Then
        XCTAssertNotNil(sentAcceptMessage)
        XCTAssertFalse(sentAcceptMessage!.destinationPublicKey.isEmpty)
    }

    func testHandleStartMessageWithAcceptFailure() {
        // Given
        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).thenThrow(AppMigrationChannelError.invalidParameters)
        }

        let coordinator = createDestinationCoordinator(
            service: service,
            destination: mockDestination
        )

        let delegate = MockAppMigrationCoordinatorDelegate()
        let expectation = XCTestExpectation(description: "Migration failed")

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).then { _, _ in
                expectation.fulfill()
            }
        }

        coordinator.delegate = delegate
        coordinator.setup()

        // When
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")
        capturedObserver?.didReceiveMigration(message: .start(startMessage))

        wait(for: [expectation], timeout: 5.0)

        // Then
        verify(delegate).appMigrationCoordinator(any(), didFailWith: any())
    }

    func testHandleCompleteMessageImportsData() throws {
        // Given - Prepare source data
        let sourceKeystore = MockKeychain()
        let sourceStorageFacade = UserDataStorageTestFacade()
        let sourceOperationQueue = OperationQueue()

        let sourceWalletSettings = SelectedWalletSettings(
            storageFacade: sourceStorageFacade,
            operationQueue: sourceOperationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            name: "Test Wallet",
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
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: sourceAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: exporter
        )

        let buildWrapper = builder.buildWrapper()
        sourceOperationQueue.addOperations(buildWrapper.allOperations, waitUntilFinished: true)
        let migrationData = try buildWrapper.targetOperation.extractNoCancellableResultData()

        // Create origin session and encrypt data
        let originSessionManager = SecureSessionManager.createForWalletMigration()
        let originPublicKey = try originSessionManager.startSession()

        // Prepare destination
        let targetKeystore = MockKeychain()
        let targetStorageFacade = UserDataStorageTestFacade()

        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()
        var sentAcceptMessage: AppMigrationMessage.Accepted?

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).then { message in
                sentAcceptMessage = message
            }
        }

        let destinationSessionManager = SecureSessionManager.createForWalletMigration()

        let coordinator = createDestinationCoordinator(
            service: service,
            destination: mockDestination,
            keystore: targetKeystore,
            storageFacade: targetStorageFacade,
            secureSessionManager: destinationSessionManager
        )

        let delegate = MockAppMigrationCoordinatorDelegate()

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        coordinator.delegate = delegate
        coordinator.setup()

        // Simulate start message to get destination public key
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")
        capturedObserver?.didReceiveMigration(message: .start(startMessage))

        guard let acceptMessage = sentAcceptMessage else {
            XCTFail("Expected accept message")
            return
        }

        // Encrypt with origin using destination's public key
        let originCryptor = try originSessionManager.deriveCryptor(peerPubKey: acceptMessage.destinationPublicKey)
        let jsonData = try JSONEncoder().encode(migrationData)
        let encryptedData = try originCryptor.encrypt(jsonData)

        let completeMessage = AppMigrationMessage.Complete(
            originPublicKey: originPublicKey,
            encryptedData: encryptedData
        )

        let expectation = XCTestExpectation(description: "Migration completed")

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).then { _ in
                expectation.fulfill()
            }
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        // When
        capturedObserver?.didReceiveMigration(message: .complete(completeMessage))

        wait(for: [expectation], timeout: 10.0)

        // Then - Verify wallet was imported
        let targetAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: targetStorageFacade)
        let walletRepository = targetAccountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchWrapper = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let targetOperationQueue = OperationQueue()
        targetOperationQueue.addOperations([fetchWrapper], waitUntilFinished: true)

        let importedWallets = try fetchWrapper.extractNoCancellableResultData()

        XCTAssertEqual(importedWallets.count, 1)
        XCTAssertEqual(importedWallets.first?.metaId, sourceWallet.metaId)
        XCTAssertEqual(importedWallets.first?.name, "Test Wallet")

        // Verify secrets were imported
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(sourceWallet.metaId)
        XCTAssertTrue(try targetKeystore.checkKey(for: entropyTag))
    }

    func testHandleCompleteMessageWithDecryptionFailure() throws {
        // Given
        let targetKeystore = MockKeychain()
        let targetStorageFacade = UserDataStorageTestFacade()

        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).thenDoNothing()
        }

        let coordinator = createDestinationCoordinator(
            service: service,
            destination: mockDestination,
            keystore: targetKeystore,
            storageFacade: targetStorageFacade
        )

        let delegate = MockAppMigrationCoordinatorDelegate()
        let expectation = XCTestExpectation(description: "Migration failed")

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).then { _, _ in
                expectation.fulfill()
            }
        }

        coordinator.delegate = delegate
        coordinator.setup()

        // Simulate start to initialize session
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")
        capturedObserver?.didReceiveMigration(message: .start(startMessage))

        // When - Send complete with invalid encrypted data
        let completeMessage = AppMigrationMessage.Complete(
            originPublicKey: Data.random(of: 65)!, // Random public key
            encryptedData: Data.random(of: 100)! // Invalid encrypted data
        )

        capturedObserver?.didReceiveMigration(message: .complete(completeMessage))

        wait(for: [expectation], timeout: 5.0)

        // Then
        verify(delegate).appMigrationCoordinator(any(), didFailWith: any())
    }

    func testHandleCompleteMessageWithImportFailure() throws {
        // Given - Create invalid migration data that will fail on import
        let originSessionManager = SecureSessionManager.createForWalletMigration()
        let originPublicKey = try originSessionManager.startSession()

        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()
        var sentAcceptMessage: AppMigrationMessage.Accepted?

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).then { message in
                sentAcceptMessage = message
            }
        }

        let destinationSessionManager = SecureSessionManager.createForWalletMigration()

        // Use a failing importer
        let failingImporter = MockAppMigrationDataImporting()
        stub(failingImporter) { stub in
            when(stub.importWrapper(migrationData: any())).then { _ in
                .createWithError(
                    AppMigrationDataImporterError.walletConversionFailed(
                        NSError(domain: "test", code: 1)
                    )
                )
            }
        }

        let coordinator = AppMigrationDestinationCoordinator(
            appMigrationService: service,
            appMigrationDestination: mockDestination,
            migrationDataImporter: failingImporter,
            secureSessionManager: destinationSessionManager,
            operationQueue: OperationQueue(),
            callbackQueue: .main,
            logger: Logger.shared
        )

        let delegate = MockAppMigrationCoordinatorDelegate()

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        coordinator.delegate = delegate
        coordinator.setup()

        // Simulate start to initialize session
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")
        capturedObserver?.didReceiveMigration(message: .start(startMessage))

        guard let acceptMessage = sentAcceptMessage else {
            XCTFail("Expected accept message")
            return
        }

        // Create valid encrypted migration data
        let migrationData = AppMigrationData(
            version: "1.0",
            migratedAt: UInt64(Date().timeIntervalSince1970),
            settings: [:],
            wallets: WalletsData(publicInfo: [], privateInfo: [])
        )

        let originCryptor = try originSessionManager.deriveCryptor(peerPubKey: acceptMessage.destinationPublicKey)
        let jsonData = try JSONEncoder().encode(migrationData)
        let encryptedData = try originCryptor.encrypt(jsonData)

        let completeMessage = AppMigrationMessage.Complete(
            originPublicKey: originPublicKey,
            encryptedData: encryptedData
        )

        let expectation = XCTestExpectation(description: "Migration failed")

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).then { _, _ in
                expectation.fulfill()
            }
        }

        // When
        capturedObserver?.didReceiveMigration(message: .complete(completeMessage))

        wait(for: [expectation], timeout: 5.0)

        // Then
        verify(delegate).appMigrationCoordinator(any(), didFailWith: any())
    }

    func testConsumesPendingMessageOnSetup() {
        // Given
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")

        let service = MockAppMigrationServiceProtocol()

        stub(service) { stub in
            when(stub.addObserver(any())).thenDoNothing()
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(.start(startMessage))
        }

        let mockDestination = MockAppMigrationDestinationProtocol()
        var sentAcceptMessage: AppMigrationMessage.Accepted?

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).then { message in
                sentAcceptMessage = message
            }
        }

        let coordinator = createDestinationCoordinator(
            service: service,
            destination: mockDestination
        )

        // When
        coordinator.setup()

        // Then - Pending message should have been processed
        XCTAssertNotNil(sentAcceptMessage)
    }

    func testFullMigrationFlow() throws {
        // This test simulates the complete migration flow between origin and destination

        // Given - Setup origin with wallet
        let sourceKeystore = MockKeychain()
        let sourceSettingsManager = InMemorySettingsManager()
        sourceSettingsManager.set(value: true, for: SettingsKey.biometryEnabled.rawValue)
        sourceSettingsManager.set(value: "JPY", for: SettingsKey.selectedCurrency.rawValue)

        let sourceStorageFacade = UserDataStorageTestFacade()
        let sourceOperationQueue = OperationQueue()

        let sourceWalletSettings = SelectedWalletSettings(
            storageFacade: sourceStorageFacade,
            operationQueue: sourceOperationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            name: "Migration Test Wallet",
            keychain: sourceKeystore,
            settings: sourceWalletSettings
        )

        guard let sourceWallet = sourceWalletSettings.value else {
            XCTFail("Source wallet should exist")
            return
        }

        // Setup origin service and mocks
        let originService = MockAppMigrationServiceProtocol()
        var originObserver: AppMigrationObserver?

        stub(originService) { stub in
            when(stub.addObserver(any())).then { observer in
                originObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockOrigin = MockAppMigrationOriginProtocol()
        var sentCompleteMessage: AppMigrationMessage.Complete?

        stub(mockOrigin) { stub in
            when(stub.start(with: any())).thenDoNothing()
            when(stub.complete(with: any())).then { message in
                sentCompleteMessage = message
            }
        }

        let originSessionManager = SecureSessionManager.createForWalletMigration()

        let sourceAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: sourceStorageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let exporter = AppMigrationWalletSecretsExporter(keychain: sourceKeystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: sourceSettingsManager,
            walletRepositoryFactory: sourceAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: exporter
        )

        let originCoordinator = AppMigrationOriginCoordinator(
            appMigrationService: originService,
            appMigrationOrigin: mockOrigin,
            migrationDataBuilder: builder,
            secureSessionManager: originSessionManager,
            operationQueue: OperationQueue(),
            callbackQueue: .main,
            logger: Logger.shared
        )

        // Setup destination service and mocks
        let targetKeystore = MockKeychain()
        let targetSettingsManager = InMemorySettingsManager()
        let targetStorageFacade = UserDataStorageTestFacade()

        let destinationService = MockAppMigrationServiceProtocol()
        var destinationObserver: AppMigrationObserver?

        stub(destinationService) { stub in
            when(stub.addObserver(any())).then { observer in
                destinationObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockDestination = MockAppMigrationDestinationProtocol()
        var sentAcceptMessage: AppMigrationMessage.Accepted?

        stub(mockDestination) { stub in
            when(stub.accept(with: any())).then { message in
                sentAcceptMessage = message
            }
        }

        let destinationSessionManager = SecureSessionManager.createForWalletMigration()

        let targetAccountRepositoryFactory = AccountRepositoryFactory(storageFacade: targetStorageFacade)
        let secretsImporter = AppMigrationWalletSecretsImporter(keychain: targetKeystore)

        let importer = AppMigrationDataImporter(
            settingsManager: targetSettingsManager,
            walletRepositoryFactory: targetAccountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: secretsImporter
        )

        let destinationCoordinator = AppMigrationDestinationCoordinator(
            appMigrationService: destinationService,
            appMigrationDestination: mockDestination,
            migrationDataImporter: importer,
            secureSessionManager: destinationSessionManager,
            operationQueue: OperationQueue(),
            callbackQueue: .main,
            logger: Logger.shared
        )

        let originDelegate = MockAppMigrationCoordinatorDelegate()
        let destinationDelegate = MockAppMigrationCoordinatorDelegate()

        stub(originDelegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        stub(destinationDelegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).thenDoNothing()
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        originCoordinator.delegate = originDelegate
        destinationCoordinator.delegate = destinationDelegate

        originCoordinator.setup()
        destinationCoordinator.setup()

        // Step 1: Destination receives start message
        let startMessage = AppMigrationMessage.Start(originScheme: "nova-old")
        destinationObserver?.didReceiveMigration(message: .start(startMessage))

        // Step 2: Origin receives accepted message from destination
        guard let acceptMessage = sentAcceptMessage else {
            XCTFail("Destination should have sent accept message")
            return
        }

        let originExpectation = XCTestExpectation(description: "Origin completed")

        stub(originDelegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).then { _ in
                originExpectation.fulfill()
            }
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        originObserver?.didReceiveMigration(message: .accepted(acceptMessage))

        wait(for: [originExpectation], timeout: 10.0)

        // Step 3: Destination receives complete message from origin
        guard let completeMessage = sentCompleteMessage else {
            XCTFail("Origin should have sent complete message")
            return
        }

        let destinationExpectation = XCTestExpectation(description: "Destination completed")

        stub(destinationDelegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).then { _ in
                destinationExpectation.fulfill()
            }
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        destinationObserver?.didReceiveMigration(message: .complete(completeMessage))

        wait(for: [destinationExpectation], timeout: 10.0)

        // Verify both sides completed successfully
        verify(originDelegate).appMigrationCoordinatorDidComplete(any())
        verify(destinationDelegate).appMigrationCoordinatorDidComplete(any())

        // Verify settings were imported
        XCTAssertEqual(targetSettingsManager.bool(for: SettingsKey.biometryEnabled.rawValue), true)
        XCTAssertEqual(targetSettingsManager.string(for: SettingsKey.selectedCurrency.rawValue), "JPY")

        // Verify wallet was imported
        let walletRepository = targetAccountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchWrapper = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let targetOperationQueue = OperationQueue()
        targetOperationQueue.addOperations([fetchWrapper], waitUntilFinished: true)

        let importedWallets = try fetchWrapper.extractNoCancellableResultData()

        XCTAssertEqual(importedWallets.count, 1)
        XCTAssertEqual(importedWallets.first?.metaId, sourceWallet.metaId)
        XCTAssertEqual(importedWallets.first?.name, "Migration Test Wallet")

        // Verify secrets were imported correctly
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(sourceWallet.metaId)
        let sourceEntropy = sourceKeystore.getRawStore()[entropyTag]
        let targetEntropy = targetKeystore.getRawStore()[entropyTag]
        XCTAssertEqual(sourceEntropy, targetEntropy)
    }
}

// MARK: - Helpers

private extension AppMigrationDestinationCoordinatorTests {
    func createDestinationCoordinator(
        service: AppMigrationServiceProtocol,
        destination: AppMigrationDestinationProtocol? = nil,
        keystore: KeystoreProtocol? = nil,
        storageFacade: StorageFacadeProtocol? = nil,
        secureSessionManager: SecureSessionManager? = nil
    ) -> AppMigrationDestinationCoordinator {
        let actualKeystore = keystore ?? MockKeychain()
        let actualStorageFacade = storageFacade ?? UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: actualStorageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let secretsImporter = AppMigrationWalletSecretsImporter(keychain: actualKeystore)

        let importer = AppMigrationDataImporter(
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsImporter: secretsImporter
        )

        let actualDestination: AppMigrationDestinationProtocol
        if let destination = destination {
            actualDestination = destination
        } else {
            let mockDestination = MockAppMigrationDestinationProtocol()
            stub(mockDestination) { stub in
                when(stub.accept(with: any())).thenDoNothing()
            }
            actualDestination = mockDestination
        }

        return AppMigrationDestinationCoordinator(
            appMigrationService: service,
            appMigrationDestination: actualDestination,
            migrationDataImporter: importer,
            secureSessionManager: secureSessionManager ?? SecureSessionManager.createForWalletMigration(),
            operationQueue: OperationQueue(),
            callbackQueue: .main,
            logger: Logger.shared
        )
    }
}
