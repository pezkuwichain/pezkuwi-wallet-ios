import Foundation
import NovaCrypto
import SubstrateSdk

enum WalletQREncoderError: Error {
    case invalidAddressEncoding
}

final class WalletQREncoder: NovaWalletQREncoderProtocol {
    let chainFormat: ChainFormat
    let publicKey: Data

    init(chainFormat: ChainFormat, publicKey: Data) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
    }

    func encode(receiverInfo: AssetReceiveInfo) throws -> Data {
        let accountId = try Data(hexString: receiverInfo.accountId)

        let address = try accountId.toAddress(using: chainFormat)

        // Tron has no `QRAddressFormat` case in the (external, unmodifiable) SubstrateSdk package
        // this app depends on, since that format was designed for substrate/ethereum only. Rather
        // than force-fitting Tron into one of those two schemas, encode the plain Base58 address
        // string directly - this is also what most Tron wallets/exchanges do for receive QR codes
        // (unlike substrate's richer "substrate:pubkey:network" scheme), so it's a safe, standard,
        // universally-scannable choice, not a workaround.
        if case .tron = chainFormat {
            guard let addressData = address.data(using: .utf8) else {
                throw WalletQREncoderError.invalidAddressEncoding
            }

            return addressData
        }

        let addressEncoder = AddressQREncoder(addressFormat: chainFormat.qrAddressFormat)

        return try addressEncoder.encode(address: address)
    }
}

final class WalletQRDecoder: NovaWalletQRDecoderProtocol {
    private let chainFormat: ChainFormat

    init(chainFormat: ChainFormat) {
        self.chainFormat = chainFormat
    }

    func decode(data _: Data) throws -> AssetReceiveInfo {
        fatalError()
    }
}

extension ChainFormat {
    var qrAddressFormat: QRAddressFormat {
        switch self {
        case .ethereum:
            return .ethereum
        case let .substrate(prefix, _):
            return .substrate(type: prefix)
        case .tron:
            // Unreachable: `WalletQREncoder.encode` special-cases `.tron` and returns before ever
            // reading this property (SubstrateSdk's `QRAddressFormat` has no Tron case to map to -
            // see the comment there). `.ethereum` is a harmless, never-read placeholder here purely
            // to satisfy exhaustiveness.
            return .ethereum
        }
    }
}

protocol NovaWalletQRCoderFactoryProtocol {
    func createEncoder() -> NovaWalletQREncoderProtocol
    func createDecoder() -> NovaWalletQRDecoderProtocol
}

protocol NovaWalletQREncoderProtocol {
    func encode(receiverInfo: AssetReceiveInfo) throws -> Data
}

protocol NovaWalletQRDecoderProtocol {
    func decode(data: Data) throws -> AssetReceiveInfo
}

final class WalletQRCoderFactory: NovaWalletQRCoderFactoryProtocol {
    let chainFormat: ChainFormat
    let publicKey: Data

    init(chainFormat: ChainFormat, publicKey: Data) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
    }

    func createEncoder() -> NovaWalletQREncoderProtocol {
        WalletQREncoder(chainFormat: chainFormat, publicKey: publicKey)
    }

    func createDecoder() -> NovaWalletQRDecoderProtocol {
        WalletQRDecoder(chainFormat: chainFormat)
    }
}
