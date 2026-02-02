import Foundation
import Foundation_iOS

public extension SecureSessionManager {
    private static let encryptionSalt = "asm-ephemeral-salt".data(using: .utf8)!
    private static let encryptionAuth = Data([2])

    static func createForAppMigration() -> SecureSessionManager {
        SecureSessionManager(
            auth: encryptionAuth,
            salt: encryptionSalt
        )
    }
}
