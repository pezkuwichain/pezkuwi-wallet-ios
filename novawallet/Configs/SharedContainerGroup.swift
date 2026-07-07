import Foundation

enum SharedContainerGroup {
    static var name: String {
        #if F_RELEASE
            return "group.io.pezkuwichain.wallet"
        #else
            return "group.io.pezkuwichain.wallet.dev"
        #endif
    }
}
