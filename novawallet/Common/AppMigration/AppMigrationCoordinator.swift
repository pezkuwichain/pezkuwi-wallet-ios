import Foundation
import Keystore_iOS
import SubstrateSdk
import Foundation_iOS

protocol AppMigrationCoordinating: AnyObject {
    func setup()
    func teardown()
}

final class AppMigrationCoordinator {
    private let appMigrationService: AppMigrationServiceProtocol
    private let appMigrationOrigin: AppMigrationOriginProtocol
    private let migrationDataBuilder: AppMigrationDataBuilding
    private let secureSessionManager: SecureSessionManager
    private let logger: LoggerProtocol

    init(
        appMigrationService: AppMigrationServiceProtocol,
        appMigrationOrigin: AppMigrationOriginProtocol,
        migrationDataBuilder: AppMigrationDataBuilding,
        secureSessionManager: SecureSessionManager,
        logger: LoggerProtocol
    ) {
        self.appMigrationService = appMigrationService
        self.appMigrationOrigin = appMigrationOrigin
        self.migrationDataBuilder = migrationDataBuilder
        self.secureSessionManager = secureSessionManager
        self.logger = logger
    }

    private func handleAcceptedMessage(_ message: AppMigrationMessage.Accepted) {
        do {
            // Build migration data
            let migrationData = try migrationDataBuilder.build()

            // Encode migration data to JSON
            let jsonData = try JSONEncoder().encode(migrationData)

            // Start secure session and get our public key
            let originPublicKey = try secureSessionManager.startSession()

            // Derive cryptor using destination's public key
            let cryptor = try secureSessionManager.deriveCryptor(peerPubKey: message.destinationPublicKey)

            // Encrypt data with the derived key
            let encryptedData = try cryptor.encrypt(jsonData)

            // Send complete message with encrypted data
            let completeMessage = AppMigrationMessage.Complete(
                originPublicKey: originPublicKey,
                encryptedData: encryptedData
            )

            try appMigrationOrigin.complete(with: completeMessage)

            logger.info("Successfully sent migration data to destination app")
        } catch {
            logger.error("Failed to handle migration acceptance: \(error)")
        }
    }

    private func handleStartMessage(_: AppMigrationMessage.Start) {
        // This would be handled by the destination app, not the origin
        logger.warning("Received start message in origin app (unexpected)")
    }

    private func handleCompleteMessage(_: AppMigrationMessage.Complete) {
        // This would be handled by the destination app, not the origin
        logger.warning("Received complete message in origin app (unexpected)")
    }
}

extension AppMigrationCoordinator: AppMigrationCoordinating {
    func setup() {
        appMigrationService.addObserver(self)

        // Check for any pending messages
        if let pendingMessage = appMigrationService.consumePendingMessage() {
            didReceiveMigration(message: pendingMessage)
        }
    }

    func teardown() {
        appMigrationService.removeObserver(self)
    }
}

extension AppMigrationCoordinator: AppMigrationObserver {
    func didReceiveMigration(message: AppMigrationMessage) {
        switch message {
        case let .start(startMessage):
            handleStartMessage(startMessage)
        case let .accepted(acceptedMessage):
            handleAcceptedMessage(acceptedMessage)
        case let .complete(completeMessage):
            handleCompleteMessage(completeMessage)
        }
    }
}
