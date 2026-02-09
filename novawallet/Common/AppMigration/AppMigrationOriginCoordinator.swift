import Foundation
import Keystore_iOS
import SubstrateSdk
import Foundation_iOS
import Operation_iOS

/// Coordinator for the origin (old) app side of migration.
/// Handles building and sending migration data when destination accepts.
final class AppMigrationOriginCoordinator {
    weak var delegate: AppMigrationCoordinatorDelegate?

    private let appMigrationService: AppMigrationServiceProtocol
    private let appMigrationOrigin: AppMigrationOriginProtocol
    private let migrationDataBuilder: AppMigrationDataBuilding
    private let secureSessionManager: SecureSessionManager
    private let operationQueue: OperationQueue
    private let callbackQueue: DispatchQueue
    private let logger: LoggerProtocol

    init(
        appMigrationService: AppMigrationServiceProtocol,
        appMigrationOrigin: AppMigrationOriginProtocol,
        migrationDataBuilder: AppMigrationDataBuilding,
        secureSessionManager: SecureSessionManager,
        operationQueue: OperationQueue,
        callbackQueue: DispatchQueue = .main,
        logger: LoggerProtocol
    ) {
        self.appMigrationService = appMigrationService
        self.appMigrationOrigin = appMigrationOrigin
        self.migrationDataBuilder = migrationDataBuilder
        self.secureSessionManager = secureSessionManager
        self.operationQueue = operationQueue
        self.callbackQueue = callbackQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension AppMigrationOriginCoordinator {
    func handleAcceptedMessage(_ message: AppMigrationMessage.Accepted) {
        logger.info("Received migration acceptance, building and sending data...")

        let buildWrapper = migrationDataBuilder.buildWrapper()

        execute(
            wrapper: buildWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: callbackQueue
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(migrationData):
                encryptAndSendMigrationData(
                    migrationData,
                    destinationPublicKey: message.destinationPublicKey
                )
            case let .failure(error):
                logger.error("Failed to build migration data: \(error)")
                delegate?.appMigrationCoordinator(self, didFailWith: error)
            }
        }
    }

    func encryptAndSendMigrationData(
        _ migrationData: AppMigrationData,
        destinationPublicKey: Data
    ) {
        do {
            // Encode migration data to JSON
            let jsonData = try JSONEncoder().encode(migrationData)

            // Start secure session and get our public key
            let originPublicKey = try secureSessionManager.startSession()

            // Derive cryptor using destination's public key
            let cryptor = try secureSessionManager.deriveCryptor(peerPubKey: destinationPublicKey)

            // Encrypt data with the derived key
            let encryptedData = try cryptor.encrypt(jsonData)

            // Send complete message with encrypted data
            let completeMessage = AppMigrationMessage.Complete(
                originPublicKey: originPublicKey,
                encryptedData: encryptedData
            )

            try appMigrationOrigin.complete(with: completeMessage)

            logger.info("Successfully sent migration data to destination app")
            delegate?.appMigrationCoordinatorDidComplete(self)
        } catch {
            logger.error("Failed to encrypt and send migration data: \(error)")
            delegate?.appMigrationCoordinator(self, didFailWith: error)
        }
    }
}

// MARK: - AppMigrationCoordinating

extension AppMigrationOriginCoordinator: AppMigrationCoordinating {
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

extension AppMigrationOriginCoordinator: AppMigrationObserver {
    func didReceiveMigration(message: AppMigrationMessage) {
        switch message {
        case .start:
            logger.warning("Origin received start message (unexpected - this is for destination)")
        case let .accepted(acceptedMessage):
            handleAcceptedMessage(acceptedMessage)
        case .complete:
            logger.warning("Origin received complete message (unexpected - this is for destination)")
        }
    }
}
