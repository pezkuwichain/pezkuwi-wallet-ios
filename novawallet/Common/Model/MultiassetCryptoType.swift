import Foundation
import SubstrateSdk

enum MultiassetCryptoType: UInt8, CaseIterable {
    case sr25519
    case ed25519
    case substrateEcdsa
    case ethereumEcdsa
    // Tron uses the identical secp256k1 curve/keccak256 pubkey scheme as Ethereum;
    // only the final address text encoding differs (Base58Check vs raw hex).
    // Appended as the last case so the persisted CoreData `cryptoType: UInt8` raw
    // values (0...3) for existing accounts are unaffected.
    case tronEcdsa
}

extension MultiassetCryptoType {
    static var substrateTypeList: [MultiassetCryptoType] {
        [.sr25519, .ed25519, .substrateEcdsa]
    }

    var utilsType: SubstrateSdk.CryptoType {
        switch self {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .substrateEcdsa, .ethereumEcdsa, .tronEcdsa:
            return .ecdsa
        }
    }

    // NOTE: `KeystoreSecretType` is defined in the external Keystore_iOS SPM package and has
    // no case of its own for Tron. Tron uses the exact same secp256k1 secret-key encoding as
    // Ethereum (raw 32-byte private key, no seed-recoverability), so `.tronEcdsa` deliberately
    // reuses `.ethereum` here. This is a judgment call, not a functional gap: it only affects how
    // the raw secret bytes are boxed/labelled for keystore storage, and does not change the value
    // that gets derived or displayed.
    var secretType: KeystoreSecretType {
        switch self {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .substrateEcdsa:
            return .ecdsa
        case .ethereumEcdsa, .tronEcdsa:
            return .ethereum
        }
    }

    var supportsSeedFromSecretKey: Bool {
        switch self {
        case .ed25519, .substrateEcdsa:
            return true
        case .sr25519, .ethereumEcdsa, .tronEcdsa:
            return false
        }
    }

    // NOTE: this reverse mapping can never produce `.tronEcdsa` since `KeystoreSecretType` has no
    // Tron case (see `secretType` above) - `.ethereum` always round-trips to `.ethereumEcdsa`. This
    // is safe for Phase 1: Tron `ChainAccountModel`s always have their `cryptoType` set explicitly
    // to `.tronEcdsa.rawValue` at creation time, never reconstructed via this initializer.
    init(secretType: KeystoreSecretType) {
        switch secretType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .ecdsa:
            self = .substrateEcdsa
        case .ethereum:
            self = .ethereumEcdsa
        }
    }
}
