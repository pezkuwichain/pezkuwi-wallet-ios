import Foundation
import Keystore_iOS
import SubstrateSdk
import Foundation_iOS
import Operation_iOS

/// Coordinator for the destination (new) app side of migration.
/// Handles accepting migration requests and importing received data.
final class AppMigrationDestinationCoordinator {
    weak var delegate: AppMigrationCoordinatorDelegate?

    private let appMigrationService: AppMigrationServiceProtocol
    private let appMigrationDestination: AppMigrationDestinationProtocol
    private let migrationDataImporter: AppMigrationDataImporting
    private let secureSessionManager: SecureSessionManager
    private let operationQueue: OperationQueue
    private let callbackQueue: DispatchQueue
    private let logger: LoggerProtocol

    init(
        appMigrationService: AppMigrationServiceProtocol,
        appMigrationDestination: AppMigrationDestinationProtocol,
        migrationDataImporter: AppMigrationDataImporting,
        secureSessionManager: SecureSessionManager,
        operationQueue: OperationQueue,
        callbackQueue: DispatchQueue = .main,
        logger: LoggerProtocol
    ) {
        self.appMigrationService = appMigrationService
        self.appMigrationDestination = appMigrationDestination
        self.migrationDataImporter = migrationDataImporter
        self.secureSessionManager = secureSessionManager
        self.operationQueue = operationQueue
        self.callbackQueue = callbackQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension AppMigrationDestinationCoordinator {
    func handleStartMessage(_ message: AppMigrationMessage.Start) {
        logger.info("Received migration start request from origin scheme: \(message.originScheme)")

        do {
            let destinationPublicKey = try secureSessionManager.startSession()

            let acceptedMessage = AppMigrationMessage.Accepted(
                destinationPublicKey: destinationPublicKey
            )

            try appMigrationDestination.accept(with: acceptedMessage)

            logger.info("Sent migration acceptance to origin app")
        } catch {
            logger.error("Failed to handle migration start: \(error)")
            delegate?.appMigrationCoordinator(self, didFailWith: error)
        }
    }

    func handleCompleteMessage(_ message: AppMigrationMessage.Complete) {
        logger.info("Received migration data, decrypting and importing...")

        do {
            let cryptor = try secureSessionManager.deriveCryptor(peerPubKey: message.originPublicKey)

            let decryptedData = try cryptor.decrypt(message.encryptedData)

            let migrationData = try JSONDecoder().decode(AppMigrationData.self, from: decryptedData)

            logger.info("Successfully decrypted migration data (version: \(migrationData.version))")

            importMigrationData(migrationData)
        } catch {
            logger.error("Failed to decrypt migration data: \(error)")
            delegate?.appMigrationCoordinator(self, didFailWith: error)
        }
    }

    func importMigrationData(_ migrationData: AppMigrationData) {
        let importWrapper = migrationDataImporter.importWrapper(migrationData: migrationData)

        execute(
            wrapper: importWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: callbackQueue
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                logger.info("Migration completed successfully")
                delegate?.appMigrationCoordinatorDidComplete(self)
            case let .failure(error):
                logger.error("Failed to import migration data: \(error)")
                delegate?.appMigrationCoordinator(self, didFailWith: error)
            }
        }
    }
}

// MARK: - AppMigrationCoordinating

extension AppMigrationDestinationCoordinator: AppMigrationCoordinating {
    func setup() {
        appMigrationService.addObserver(self)

        guard let pendingMessage = appMigrationService.consumePendingMessage() else { return }

        didReceiveMigration(message: pendingMessage)
    }

    func teardown() {
        appMigrationService.removeObserver(self)
    }
}

// MARK: - AppMigrationObserver

extension AppMigrationDestinationCoordinator: AppMigrationObserver {
    func didReceiveMigration(message: AppMigrationMessage) {
        switch message {
        case let .start(startMessage):
            handleStartMessage(startMessage)
        case .accepted:
            logger.warning("Destination received accepted message (unexpected - this is for origin)")
        case let .complete(completeMessage):
            handleCompleteMessage(completeMessage)
        }
    }
}
