import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import Cuckoo

final class AppMigrationOriginCoordinatorTests: XCTestCase {
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

        let coordinator = createOriginCoordinator(service: service)

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

        let coordinator = createOriginCoordinator(service: service)

        coordinator.setup()
        coordinator.teardown()

        // Then
        XCTAssertTrue(observerRemoved)
    }

    func testHandleAcceptedMessageSendsEncryptedData() throws {
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

        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
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

        let coordinator = createOriginCoordinator(
            service: service,
            origin: mockOrigin,
            keystore: keystore,
            storageFacade: storageFacade
        )

        let delegate = MockAppMigrationCoordinatorDelegate()
        let expectation = XCTestExpectation(description: "Migration completed")

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).then { _ in
                expectation.fulfill()
            }
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        coordinator.delegate = delegate
        coordinator.setup()

        // When - Simulate destination accepting migration
        let destinationSessionManager = SecureSessionManager.createForWalletMigration()
        let destinationPublicKey = try destinationSessionManager.startSession()

        let acceptedMessage = AppMigrationMessage.Accepted(destinationPublicKey: destinationPublicKey)
        capturedObserver?.didReceiveMigration(message: .accepted(acceptedMessage))

        wait(for: [expectation], timeout: 10.0)

        // Then
        XCTAssertNotNil(sentCompleteMessage)

        guard let completeMessage = sentCompleteMessage else {
            XCTFail("Expected complete message")
            return
        }

        // Verify the encrypted data can be decrypted by destination
        let cryptor = try destinationSessionManager.deriveCryptor(peerPubKey: completeMessage.originPublicKey)
        let decryptedData = try cryptor.decrypt(completeMessage.encryptedData)
        let migrationData = try JSONDecoder().decode(AppMigrationData.self, from: decryptedData)

        XCTAssertEqual(migrationData.version, "1.0")
        XCTAssertFalse(migrationData.wallets.publicInfo.isEmpty)
    }

    func testHandleAcceptedMessageWithBuildFailure() {
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

        let mockOrigin = MockAppMigrationOriginProtocol()

        stub(mockOrigin) { stub in
            when(stub.start(with: any())).thenDoNothing()
            when(stub.complete(with: any())).thenDoNothing()
        }

        // Use a builder that will fail
        let failingBuilder = MockFailingMigrationDataBuilder()

        let coordinator = AppMigrationOriginCoordinator(
            appMigrationService: service,
            appMigrationOrigin: mockOrigin,
            migrationDataBuilder: failingBuilder,
            secureSessionManager: SecureSessionManager.createForWalletMigration(),
            operationQueue: OperationQueue(),
            callbackQueue: .main,
            logger: Logger.shared
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
        let publicKey = Data.random(of: 32)!
        let acceptedMessage = AppMigrationMessage.Accepted(destinationPublicKey: publicKey)
        capturedObserver?.didReceiveMigration(message: .accepted(acceptedMessage))

        wait(for: [expectation], timeout: 5.0)

        // Then - Verify failure was reported
        verify(delegate).appMigrationCoordinator(any(), didFailWith: any())
    }

    func testHandleAcceptedMessageWithSendFailure() throws {
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

        let service = MockAppMigrationServiceProtocol()
        var capturedObserver: AppMigrationObserver?

        stub(service) { stub in
            when(stub.addObserver(any())).then { observer in
                capturedObserver = observer
            }
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(nil)
        }

        let mockOrigin = MockAppMigrationOriginProtocol()

        stub(mockOrigin) { stub in
            when(stub.start(with: any())).thenDoNothing()
            when(stub.complete(with: any())).thenThrow(AppMigrationChannelError.invalidParameters)
        }

        let coordinator = createOriginCoordinator(
            service: service,
            origin: mockOrigin,
            keystore: keystore,
            storageFacade: storageFacade
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
        let destinationSessionManager = SecureSessionManager.createForWalletMigration()
        let destinationPublicKey = try destinationSessionManager.startSession()

        let acceptedMessage = AppMigrationMessage.Accepted(destinationPublicKey: destinationPublicKey)
        capturedObserver?.didReceiveMigration(message: .accepted(acceptedMessage))

        wait(for: [expectation], timeout: 10.0)

        // Then
        verify(delegate).appMigrationCoordinator(any(), didFailWith: any())
    }

    func testConsumesPendingMessageOnSetup() throws {
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

        // Set pending message before setup
        let destinationSessionManager = SecureSessionManager.createForWalletMigration()
        let destinationPublicKey = try destinationSessionManager.startSession()
        let acceptedMessage = AppMigrationMessage.Accepted(destinationPublicKey: destinationPublicKey)

        let service = MockAppMigrationServiceProtocol()

        stub(service) { stub in
            when(stub.addObserver(any())).thenDoNothing()
            when(stub.removeObserver(any())).thenDoNothing()
            when(stub.consumePendingMessage()).thenReturn(.accepted(acceptedMessage))
        }

        let mockOrigin = MockAppMigrationOriginProtocol()
        var sentCompleteMessage: AppMigrationMessage.Complete?

        stub(mockOrigin) { stub in
            when(stub.start(with: any())).thenDoNothing()
            when(stub.complete(with: any())).then { message in
                sentCompleteMessage = message
            }
        }

        let coordinator = createOriginCoordinator(
            service: service,
            origin: mockOrigin,
            keystore: keystore,
            storageFacade: storageFacade
        )

        let delegate = MockAppMigrationCoordinatorDelegate()
        let expectation = XCTestExpectation(description: "Pending message processed")

        stub(delegate) { stub in
            when(stub.appMigrationCoordinatorDidComplete(any())).then { _ in
                expectation.fulfill()
            }
            when(stub.appMigrationCoordinator(any(), didFailWith: any())).thenDoNothing()
        }

        coordinator.delegate = delegate

        // When
        coordinator.setup()

        wait(for: [expectation], timeout: 10.0)

        // Then
        XCTAssertNotNil(sentCompleteMessage)
        verify(delegate).appMigrationCoordinatorDidComplete(any())
    }

    // MARK: - Helpers

    private func createOriginCoordinator(
        service: AppMigrationServiceProtocol,
        origin: AppMigrationOriginProtocol? = nil,
        keystore: KeystoreProtocol? = nil,
        storageFacade: StorageFacadeProtocol? = nil
    ) -> AppMigrationOriginCoordinator {
        let actualKeystore = keystore ?? MockKeychain()
        let actualStorageFacade = storageFacade ?? UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: actualStorageFacade)
        let walletConverter = CloudBackupFileModelConverter()
        let exporter = AppMigrationWalletSecretsExporter(keychain: actualKeystore)

        let builder = AppMigrationDataBuilder(
            settingsManager: InMemorySettingsManager(),
            walletRepositoryFactory: accountRepositoryFactory,
            walletConverter: walletConverter,
            walletSecretsExporter: exporter
        )

        let actualOrigin: AppMigrationOriginProtocol
        if let origin = origin {
            actualOrigin = origin
        } else {
            let mockOrigin = MockAppMigrationOriginProtocol()
            stub(mockOrigin) { stub in
                when(stub.start(with: any())).thenDoNothing()
                when(stub.complete(with: any())).thenDoNothing()
            }
            actualOrigin = mockOrigin
        }

        return AppMigrationOriginCoordinator(
            appMigrationService: service,
            appMigrationOrigin: actualOrigin,
            migrationDataBuilder: builder,
            secureSessionManager: SecureSessionManager.createForWalletMigration(),
            operationQueue: OperationQueue(),
            callbackQueue: .main,
            logger: Logger.shared
        )
    }
}

// MARK: - Mock Failing Builder

private final class MockFailingMigrationDataBuilder: AppMigrationDataBuilding {
    func buildWrapper() -> CompoundOperationWrapper<AppMigrationData> {
        let operation = ClosureOperation<AppMigrationData> {
            throw AppMigrationDataBuilderError.walletConversionFailed(
                NSError(domain: "test", code: 1)
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
