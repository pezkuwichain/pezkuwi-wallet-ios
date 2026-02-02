import Foundation

// MARK: - Keypair

public struct AppMigrationKeypair {
    public typealias PublicKey = Data
    public typealias PrivateKey = Data

    public let publicKey: PublicKey
    public let privateKey: PrivateKey

    public init(publicKey: PublicKey, privateKey: PrivateKey) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}

// MARK: - Actions

public enum AppMigrationAction: String, Equatable {
    case migrate
    case migrateAccepted = "migrate-accepted"
    case migrateComplete = "migrate-complete"
}

// MARK: - Query Keys

enum AppMigrationQueryKey: String {
    case action
    case key
    case encryptedData = "data"
    case scheme
}

// MARK: - Domains

enum AppMigrationDomain: String {
    case origin = "asm-origin"
    case destination = "asm-destination"
}

// MARK: - Params

enum AppMigrationParams {
    static let allowedAppLinkSchemes: Set<String> = ["https", "http"]
}

// MARK: - Messages

public enum AppMigrationMessage: Equatable {
    public struct Start: Equatable {
        public let originScheme: String

        public init(originScheme: String) {
            self.originScheme = originScheme
        }
    }

    public struct Accepted: Equatable {
        public let destinationPublicKey: AppMigrationKeypair.PublicKey

        public init(destinationPublicKey: AppMigrationKeypair.PublicKey) {
            self.destinationPublicKey = destinationPublicKey
        }
    }

    public struct Complete: Equatable {
        public let originPublicKey: AppMigrationKeypair.PublicKey
        public let encryptedData: Data

        public init(
            originPublicKey: AppMigrationKeypair.PublicKey,
            encryptedData: Data
        ) {
            self.originPublicKey = originPublicKey
            self.encryptedData = encryptedData
        }
    }

    case start(Start)
    case accepted(Accepted)
    case complete(Complete)
}
