import Foundation
import Keystore_iOS
import Operation_iOS

protocol AppMigrationDataImporting {
    func importWrapper(migrationData: AppMigrationData) -> CompoundOperationWrapper<Void>
}

enum AppMigrationDataImporterError: Error {
    case walletConversionFailed(Error)
    case secretsImportFailed(Error)
    case walletSaveFailed(Error)
    case settingsImportFailed(Error)
}

final class AppMigrationDataImporter {
    private let settingsManager: SettingsManagerProtocol
    private let walletRepositoryFactory: AccountRepositoryFactoryProtocol
    private let walletConverter: CloudBackupFileModelConverting
    private let walletSecretsImporter: AppMigrationWalletSecretsImporting

    init(
        settingsManager: SettingsManagerProtocol,
        walletRepositoryFactory: AccountRepositoryFactoryProtocol,
        walletConverter: CloudBackupFileModelConverting,
        walletSecretsImporter: AppMigrationWalletSecretsImporting
    ) {
        self.settingsManager = settingsManager
        self.walletRepositoryFactory = walletRepositoryFactory
        self.walletConverter = walletConverter
        self.walletSecretsImporter = walletSecretsImporter
    }
}

// MARK: - Private

private extension AppMigrationDataImporter {
    func importSettings(_ settings: [String: CodableValue]) {
        settings.forEach { key, settingValue in
            switch settingValue {
            case let .bool(boolValue):
                settingsManager.set(value: boolValue, for: key)
            case let .int(intValue):
                settingsManager.set(value: intValue, for: key)
            case let .double(doubleValue):
                settingsManager.set(value: doubleValue, for: key)
            case let .string(stringValue):
                settingsManager.set(value: stringValue, for: key)
            case let .data(dataValue):
                settingsManager.set(value: dataValue, for: key)
            case .null:
                settingsManager.removeValue(for: key)
            }
        }
    }
}

// MARK: - AppMigrationDataImporting

extension AppMigrationDataImporter: AppMigrationDataImporting {
    func importWrapper(migrationData: AppMigrationData) -> CompoundOperationWrapper<Void> {
        let walletRepository = walletRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // Convert public info to wallet models
        let wallets: Set<MetaAccountModel>
        do {
            wallets = try walletConverter.convertFromPublicInfo(
                models: migrationData.wallets.publicInfo
            )

            // Import settings
            importSettings(migrationData.settings)

            // Import wallet secrets to keychain
            let privateDataByWalletId = migrationData
                .wallets
                .privateInfo
                .reduce(into: [:]) { $0[$1.walletId] = $1 }

            try wallets.forEach { wallet in
                guard let privateInfo = privateDataByWalletId[wallet.metaId] else { return }

                do {
                    try self.walletSecretsImporter.importSecrets(
                        for: wallet,
                        privateInfo: privateInfo
                    )
                } catch {
                    throw AppMigrationDataImporterError.secretsImportFailed(error)
                }
            }

            // Save wallets to repository
            let saveOperation = walletRepository.saveOperation(
                {
                    wallets.enumerated().map { index, wallet in
                        ManagedMetaAccountModel(
                            info: wallet,
                            isSelected: index == 0,
                            order: UInt32(index)
                        )
                    }
                },
                { [] }
            )

            return CompoundOperationWrapper(targetOperation: saveOperation)
        } catch {
            return .createWithError(AppMigrationDataImporterError.walletConversionFailed(error))
        }
    }
}
