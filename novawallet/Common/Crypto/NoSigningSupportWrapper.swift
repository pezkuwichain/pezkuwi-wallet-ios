import Foundation
import NovaCrypto

enum NoSigningSupportType {
    case paritySigner
    case ledger
    case polkadotVault
    case proxy
    case multisig
}

enum NoSigningSupportError: Error {
    case notSupported(type: NoSigningSupportType)
}

// Phase 1 Tron support is read-only (balances/receive address display only) - signing/broadcast
// is explicitly out of scope for this phase and left for a dedicated future review. Kept separate
// from `NoSigningSupportError`/`NoSigningSupportType` above since those drive an exhaustively
// switched, user-facing "hardware wallet not supported" UI sheet (`MessageSheetViewFactory`) that
// would need new icons/localized strings for a real hardware-wallet family; this error is only
// reachable from internal signing/verification code paths that Phase 1 never wires up for Tron.
enum TronSigningNotImplementedError: Error {
    case notImplemented
}

final class NoSigningSupportWrapper: SigningWrapperProtocol {
    let type: NoSigningSupportType

    init(type: NoSigningSupportType) {
        self.type = type
    }

    func sign(_: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        throw NoSigningSupportError.notSupported(type: type)
    }
}
