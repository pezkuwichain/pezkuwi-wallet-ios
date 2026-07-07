import Foundation
import NovaCrypto
import SubstrateSdk

protocol SignatureCreatorProtocol: AnyObject {
    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol
}

protocol SigningWrapperProtocol: SignatureCreatorProtocol {}

extension SigningWrapperProtocol {
    func signSr25519(_ originalData: Data, secretKeyData: Data, publicKeyData: Data) throws
        -> IRSignatureProtocol {
        let privateKey = try SNPrivateKey(rawData: secretKeyData)
        let publicKey = try SNPublicKey(rawData: publicKeyData)

        let signer = SNSigner(keypair: SNKeypair(privateKey: privateKey, publicKey: publicKey))
        let signature = try signer.sign(originalData)

        return signature
    }

    func signEd25519(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = Ed25519KeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = EDSigner(privateKey: privateKey)

        return try signer.sign(originalData)
    }

    func signEcdsa(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = try originalData.blake2b32()
        return try signer.sign(hashedData)
    }

    func signEthereum(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = try originalData.keccak256()
        return try signer.sign(hashedData)
    }

    // Tron uses the identical secp256k1/BIP32 key material as Ethereum (see
    // `MetaAccountOperationFactory+Secrets.swift`'s Tron derivation comment and
    // `MultiassetCryptoType.tronEcdsa`) and the same `SECSigner` recoverable-ECDSA primitive - only
    // the pre-signing hash function differs (SHA-256 here vs Keccak-256 for `signEthereum` above).
    //
    // This was independently verified against two real, already-broadcast transactions fetched
    // live from Shasta testnet (2026): `sha256(raw_data_bytes)` was confirmed to equal exactly the
    // `txID` TronGrid itself reports for that transaction, and recovering the public key from that
    // transaction's real on-chain signature against that same `sha256(raw_data)` digest (trying
    // both secp256k1 recovery candidates) produced the point whose Keccak-256-derived address
    // matched the transaction's real `owner_address` - confirming both the digest (SHA-256, not
    // Keccak-256) and that no other transformation of `raw_data` happens before signing.
    //
    // `SECSigner.sign(_:)` returns a 65-byte `r(32) || s(32) || recid(1)` recoverable signature
    // with `recid` as the *raw* secp256k1 recovery id (0 or 1) - this is NOT yet in Tron's expected
    // wire format. Tron (like classic, pre-EIP-155 Ethereum message signatures) expects the final
    // byte to be `recid + 27` (confirmed both by recovering `recid` from that same real signature
    // above - the actual on-chain byte was `28 = 27 + 1` - and independently by reading
    // TronGrid/TronWeb's own reference signing code, `ECKeySign` in
    // `tronprotocol/tronweb/src/utils/crypto.ts`, which does exactly `signature.recovery! + 27`).
    // That `+27` remapping is Tron-wire-format-specific, not a generic signing-primitive concern,
    // so it deliberately does NOT happen here - it's applied at the call site that assembles the
    // final TronGrid `broadcasttransaction` request (see `TronTransactionService`).
    func signTron(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = originalData.sha256()
        return try signer.sign(hashedData)
    }
}
