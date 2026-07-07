import Foundation

/**
 * Generic Base58Check codec (Bitcoin-style: version byte + payload + 4-byte double-SHA256
 * checksum, all Base58-encoded). Used by Tron address encoding (`ChainFormat.tron`), whose
 * addresses are `Base58Check(0x41 || <20-byte account id>)`.
 *
 * Verified against two independent, non-Tron test vectors during implementation (see PR notes):
 *   - Bitcoin genesis address `1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa` from its known hash160 with
 *     version byte `0x00`, confirming the checksum/encoding algorithm in isolation.
 *   - The standard BIP39 test mnemonic's Ethereum address at path `m/44'/60'/0'/0/0`
 *     (`0x9858EfFD232B4033E47d90003D41EC34EcaEda94`), confirming the BIP32/secp256k1/keccak256
 *     pipeline that feeds into the Tron-specific payload.
 * Both were executed with independent, well-tested Rust crates (bip39, tiny-hderive, k256,
 * tiny-keccak, sha2, bs58) outside of this app, not with this Swift code (no Xcode available in
 * this environment) - they validate the *algorithm*, not this exact Swift implementation.
 */
enum Base58Check {
    enum Base58CheckError: Error {
        case invalidChecksum
        case tooShort
    }

    static func encode(payload: Data, versionByte: UInt8) -> String {
        var full = Data([versionByte])
        full.append(payload)

        let checksum = full.sha256().sha256().prefix(4)
        full.append(contentsOf: checksum)

        return full.base58EncodedString()
    }

    /// Decodes a Base58Check string, verifying the checksum and returning the version byte
    /// alongside the payload that follows it (i.e. NOT including the version byte itself).
    static func decode(_ string: String) throws -> (versionByte: UInt8, payload: Data) {
        guard let raw = Data(base58btcEncoded: string), raw.count > 4 else {
            throw Base58CheckError.tooShort
        }

        let body = raw.prefix(raw.count - 4)
        let checksum = raw.suffix(4)

        let expectedChecksum = body.sha256().sha256().prefix(4)

        guard checksum == expectedChecksum else {
            throw Base58CheckError.invalidChecksum
        }

        let versionByte = body[body.startIndex]
        let payload = body.dropFirst()

        return (versionByte, Data(payload))
    }
}
