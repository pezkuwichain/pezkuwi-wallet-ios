import Foundation
import Keystore_iOS
import SubstrateSdk
import NovaCrypto

protocol AppMigrationWalletSecretsImporting {
    func importSecrets(
        for wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws
}

final class AppMigrationWalletSecretsImporter {
    private let keychain: KeystoreProtocol

    init(keychain: KeystoreProtocol) {
        self.keychain = keychain
    }
}

// MARK: - Private

private extension AppMigrationWalletSecretsImporter {
    func saveEntropy(_ entropy: String, wallet: MetaAccountModel, accountId: AccountId?) throws {
        let entropyData = try Data(hexString: entropy)
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)
        try keychain.saveKey(entropyData, with: tag)
    }

    func saveSeed(
        _ seed: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        let seedData = try Data(hexString: seed)
        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId)
        try keychain.saveKey(seedData, with: tag)
    }

    func savePrivateKey(
        _ secrets: CloudBackup.DecryptedFileModel.KeypairSecrets,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

        let privateKeyData = try Data(hexString: secrets.privateKey)

        if let nonceHex = secrets.nonce {
            let nonce = try Data(hexString: nonceHex)
            try keychain.saveKey(privateKeyData + nonce, with: tag)
        } else {
            try keychain.saveKey(privateKeyData, with: tag)
        }
    }

    func saveDerivationPath(
        _ derivationPath: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        switch wallet.type {
        case .secrets, .paritySigner, .polkadotVault, .proxied, .watchOnly, .multisig:
            try saveRegularDerivationPath(
                derivationPath,
                wallet: wallet,
                accountId: accountId,
                isEthereumBased: isEthereumBased
            )
        case .ledger, .genericLedger:
            try saveLedgerDerivationPath(
                derivationPath,
                wallet: wallet,
                accountId: accountId,
                isEthereumBased: isEthereumBased
            )
        }
    }

    func saveRegularDerivationPath(
        _ derivationPath: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        guard let derivationPathData = derivationPath.asSecretData(), !derivationPathData.isEmpty else {
            return
        }

        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)
        try keychain.saveKey(derivationPathData, with: tag)
    }

    func saveLedgerDerivationPath(
        _ derivationPath: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        guard !derivationPath.isEmpty else {
            return
        }

        let derivationPathData = try LedgerPathConverter().convertToChaincodesData(from: derivationPath)

        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)

        try keychain.saveKey(derivationPathData, with: tag)
    }

    func importUniversalWalletSecrets(
        _ wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws {
        if let entropyHex = privateInfo.entropy {
            try saveEntropy(entropyHex, wallet: wallet, accountId: nil)
        }

        if let substrate = privateInfo.substrate {
            if let derivationPath = substrate.derivationPath {
                try saveDerivationPath(derivationPath, wallet: wallet, accountId: nil, isEthereumBased: false)
            }

            if let seedHex = substrate.seed {
                try saveSeed(seedHex, wallet: wallet, accountId: nil, isEthereumBased: false)
            }

            if let keypair = substrate.keypair {
                try savePrivateKey(keypair, wallet: wallet, accountId: nil, isEthereumBased: false)
            }
        }

        if let ethereum = privateInfo.ethereum {
            if let derivationPath = ethereum.derivationPath {
                try saveDerivationPath(derivationPath, wallet: wallet, accountId: nil, isEthereumBased: true)
            }

            if let seedHex = ethereum.seed {
                try saveSeed(seedHex, wallet: wallet, accountId: nil, isEthereumBased: true)
            }

            if let keypair = ethereum.keypair {
                try savePrivateKey(keypair, wallet: wallet, accountId: nil, isEthereumBased: true)
            }
        }
    }

    func importChainAccountsSecrets(
        _ wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws {
        for backupChainAccount in privateInfo.chainAccounts {
            let accountId = try Data(hexString: backupChainAccount.accountId)

            if let entropy = backupChainAccount.entropy {
                try saveEntropy(entropy, wallet: wallet, accountId: accountId)
            }

            guard let chainAccount = wallet.chainAccounts.first(where: { $0.accountId == accountId }) else {
                continue
            }

            if let seed = backupChainAccount.seed {
                try saveSeed(
                    seed,
                    wallet: wallet,
                    accountId: accountId,
                    isEthereumBased: chainAccount.isEthereumBased
                )
            }

            if let derivationPath = backupChainAccount.derivationPath {
                try saveDerivationPath(
                    derivationPath,
                    wallet: wallet,
                    accountId: accountId,
                    isEthereumBased: chainAccount.isEthereumBased
                )
            }

            if let keypair = backupChainAccount.keypair {
                try savePrivateKey(
                    keypair,
                    wallet: wallet,
                    accountId: accountId,
                    isEthereumBased: chainAccount.isEthereumBased
                )
            }
        }
    }
}

// MARK: - AppMigrationWalletSecretsImporting

extension AppMigrationWalletSecretsImporter: AppMigrationWalletSecretsImporting {
    func importSecrets(
        for wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws {
        try importUniversalWalletSecrets(wallet, privateInfo: privateInfo)
        try importChainAccountsSecrets(wallet, privateInfo: privateInfo)
    }
}
