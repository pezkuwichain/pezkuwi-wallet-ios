import Foundation
import SubstrateSdk
import NovaCrypto
import Operation_iOS
import Keystore_iOS

extension MetaAccountOperationFactory {
    func newSecretsMetaAccountOperation(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(from: request.derivationPath, ethereumBased: false)

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: mnemonic.toString(),
                password: password,
                ethereumBased: false
            )

            let substrateKeypair = try generateKeypair(
                from: seedResult.seed.miniSeed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                type: .secrets,
                publicKey: substrateKeypair.publicKey,
                cryptoType: request.cryptoType
            )

            let ethereumJunctionResult = try getJunctionResult(
                from: request.ethereumDerivationPath,
                ethereumBased: true
            )

            let ethereumChaincodes = ethereumJunctionResult?.chaincodes ?? []

            let ethereumSeedFactory = BIP32SeedFactory()
            let ethereumSeedResult = try ethereumSeedFactory.deriveSeed(from: mnemonic.toString(), password: password)

            let keypairFactory = createKeypairFactory(.ethereumEcdsa)

            let ethereumKeypair = try keypairFactory.createKeypairFromSeed(
                ethereumSeedResult.seed,
                chaincodeList: ethereumChaincodes
            )

            let ethereumSecretKey = ethereumKeypair.privateKey().rawData()
            let ethereumPublicKey = ethereumKeypair.publicKey().rawData()
            let ethereumAddress = try ethereumPublicKey.ethereumAddressFromPublicKey()

            // Tron: same secp256k1/BIP32 derivation mechanics as Ethereum above, but its own
            // BIP44 coin-type path (`DerivationPathConstants.defaultTron`, coin type 195) and its
            // own keystore tag namespace. Unlike Ethereum, Tron has no master-key slot on
            // `MetaAccountModel` (avoiding a Core Data migration) - it is stored as a dedicated
            // per-chain `ChainAccountModel` for `KnowChainId.tron`, attached below via
            // `replacingChainAccount`. The raw 20-byte account id is computed exactly like
            // Ethereum's (`keccak256(pubkey)[-20:]`, via the same `ethereumAddressFromPublicKey()`
            // helper) - only the *display* encoding differs (Base58Check with a 0x41 version byte,
            // applied later by `ChainFormat.tron`), so reusing that helper here is intentional and
            // correct, not a shortcut.
            let tronJunctionResult = try getJunctionResult(
                from: DerivationPathConstants.defaultTron,
                ethereumBased: true
            )

            let tronChaincodes = tronJunctionResult?.chaincodes ?? []

            let tronSeedFactory = BIP32SeedFactory()
            let tronSeedResult = try tronSeedFactory.deriveSeed(from: mnemonic.toString(), password: password)

            let tronKeypairFactory = createKeypairFactory(.tronEcdsa)

            let tronKeypair = try tronKeypairFactory.createKeypairFromSeed(
                tronSeedResult.seed,
                chaincodeList: tronChaincodes
            )

            let tronSecretKey = tronKeypair.privateKey().rawData()
            let tronPublicKey = tronKeypair.publicKey().rawData()
            let tronAccountId = try tronPublicKey.ethereumAddressFromPublicKey()

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateKeypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seedResult.seed.miniSeed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumSecretKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumSeedResult.seed, metaId: metaId, ethereumBased: true)

            try saveTronSecretKey(tronSecretKey, metaId: metaId, accountId: tronAccountId)
            try saveTronDerivationPath(
                DerivationPathConstants.defaultTron,
                metaId: metaId,
                accountId: tronAccountId
            )
            try saveTronSeed(tronSeedResult.seed, metaId: metaId, accountId: tronAccountId)

            try saveEntropy(mnemonic.entropy(), metaId: metaId)

            let tronChainAccount = ChainAccountModel(
                chainId: KnowChainId.tron,
                accountId: tronAccountId,
                publicKey: tronPublicKey,
                cryptoType: MultiassetCryptoType.tronEcdsa.rawValue,
                proxy: nil,
                multisig: nil
            )

            return metaAccount.replacingEthereumPublicKey(ethereumPublicKey)
                .replacingEthereumAddress(ethereumAddress)
                .replacingChainAccount(tronChainAccount)
        }
    }

    func newSecretsMetaAccountOperation(request: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: false
            )

            let chaincodes = junctionResult?.chaincodes ?? []
            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                type: .secrets,
                publicKey: keypair.publicKey,
                cryptoType: request.cryptoType
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(keypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seed, metaId: metaId, ethereumBased: false)

            return metaAccount
        }
    }

    func newSecretsMetaAccountOperation(request: MetaAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: data
            )

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password)
            else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .substrateEcdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            case .ethereumEcdsa, .tronEcdsa:
                throw AccountCreationError.unsupportedNetwork
            }

            let metaId = UUID().uuidString
            let accountId = try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(keystore.secretKeyData, metaId: metaId, ethereumBased: false)

            return MetaAccountModel(
                metaId: metaId,
                name: request.username,
                substrateAccountId: accountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: publicKey.rawData(),
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .secrets,
                multisig: nil
            )
        }
    }

    func newSecretsMetaAccountOperation(request: MetaAccountImportKeypairRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: false
            )

            let chaincodes = junctionResult?.chaincodes ?? []

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                type: .secrets,
                publicKey: request.publicKey,
                cryptoType: request.cryptoType
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(request.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)

            return metaAccount
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            // NOTE: this generic "add chain account from mnemonic" path is not wired up to any
            // Tron UI entry point in Phase 1 (read-only support only). Guard explicitly rather
            // than silently mis-deriving: falling through with `ethereumBased == false` would
            // save the secret key under the substrate tag namespace and derive the account id via
            // `publicKeyToAccountId()` (blake2-based), which is wrong for a secp256k1 Tron key.
            guard request.cryptoType != .tronEcdsa else {
                throw AccountCreationError.unsupportedNetwork
            }

            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: ethereumBased
            )

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: request.mnemonic,
                password: password,
                ethereumBased: ethereumBased
            )

            let seed = ethereumBased ? seedResult.seed : seedResult.seed.miniSeed
            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let publicKey = keypair.publicKey
            let accountId = ethereumBased ? try publicKey.ethereumAddressFromPublicKey() :
                try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                keypair.secretKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: ethereumBased)
            try saveEntropy(seedResult.mnemonic.entropy(), metaId: metaId, accountId: accountId)

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportSeedRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            // See the matching guard/comment in the mnemonic-based overload above.
            guard request.cryptoType != .tronEcdsa else {
                throw AccountCreationError.unsupportedNetwork
            }

            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: ethereumBased
            )

            let chaincodes = junctionResult?.chaincodes ?? []

            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let publicKey = keypair.publicKey
            let accountId = ethereumBased ? try publicKey.ethereumAddressFromPublicKey() :
                try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                keypair.secretKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: ethereumBased)

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportKeypairRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            // See the matching guard/comment in the mnemonic-based overload above.
            guard request.cryptoType != .tronEcdsa else {
                throw AccountCreationError.unsupportedNetwork
            }

            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let publicKey = request.publicKey
            let accountId = ethereumBased
                ? try publicKey.ethereumAddressFromPublicKey()
                : try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                request.secretKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportKeystoreRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            // See the matching guard/comment in the mnemonic-based overload above.
            guard request.cryptoType != .tronEcdsa else {
                throw AccountCreationError.unsupportedNetwork
            }

            let ethereumBased = request.cryptoType == .ethereumEcdsa

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: data
            )

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password)
            else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .substrateEcdsa, .ethereumEcdsa, .tronEcdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            }

            let metaId = UUID().uuidString
            let accountId = ethereumBased ? try publicKey.rawData().ethereumAddressFromPublicKey() :
                try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: metaAccount.metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey.rawData(),
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            try self.saveSecretKey(keystore.secretKeyData, metaId: metaId, ethereumBased: false)

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }
}
