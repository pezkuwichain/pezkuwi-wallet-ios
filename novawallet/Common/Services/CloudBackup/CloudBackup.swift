import Foundation

enum CloudBackup {
    static let walletsFilename = "wallets.novawallet"

    static var containerId: String {
        #if F_RELEASE
            "iCloud.io.pezkuwichain.wallet.Documents"
        #else
            "iCloud.io.pezkuwichain.wallet.dev.Documents"
        #endif
    }
}
