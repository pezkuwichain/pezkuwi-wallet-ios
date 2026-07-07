import Foundation

struct PolkadotExtensionAccount: Encodable {
    let address: String
    let genesisHash: String?
    let name: String?
    let type: PolkadotExtensionKeypairType?
}

enum PolkadotExtensionKeypairType: String, Encodable {
    case sr25519
    case ed25519
    case ecdsa
    case ethereum

    init(cryptoType: MultiassetCryptoType) {
        switch cryptoType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .substrateEcdsa:
            self = .ecdsa
        case .ethereumEcdsa:
            self = .ethereum
        case .tronEcdsa:
            // Unreachable: Tron chains are not `isEthereumBased`, so they are excluded from the
            // in-app DApp browser's injected-provider (`window.ethereum`/`injectedWeb3`) surface
            // entirely (see `DAppBrowserSigningChainResolver`/`DAppBrowserStateDataSource`, which
            // filter on `isEthereumBased`). Tron would need its own TronLink-style
            // `window.tronWeb` injection protocol, which Phase 1 does not implement.
            self = .ethereum
        }
    }
}
