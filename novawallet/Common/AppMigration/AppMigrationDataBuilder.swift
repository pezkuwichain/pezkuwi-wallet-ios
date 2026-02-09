import Foundation
import Keystore_iOS
import SubstrateSdk
import Operation_iOS

protocol AppMigrationDataBuilding {
    func buildWrapper() -> CompoundOperationWrapper<AppMigrationData>
}

enum AppMigrationDataBuilderError: Error {
    case walletConversionFailed(Error)
    case secretsExportFailed(Error)
}

final class AppMigrationDataBuilder {
    private let settingsManager: SettingsManagerProtocol
    private let walletRepositoryFactory: AccountRepositoryFactoryProtocol
    private let walletConverter: CloudBackupFileModelConverting
    private let walletSecretsExporter: AppMigrationWalletSecretsExporting

    init(
        settingsManager: SettingsManagerProtocol,
        walletRepositoryFactory: AccountRepositoryFactoryProtocol,
        walletConverter: CloudBackupFileModelConverting,
        walletSecretsExporter: AppMigrationWalletSecretsExporting
    ) {
        self.settingsManager = settingsManager
        self.walletRepositoryFactory = walletRepositoryFactory
        self.walletConverter = walletConverter
        self.walletSecretsExporter = walletSecretsExporter
    }

    private func buildSettings() -> [String: CodableValue] {
        SettingsKey.allCases.reduce(into: [:]) {
            $0[$1.rawValue] = CodableValue.from(anyValue: settingsManager.anyValue(for: $1.rawValue))
        }
    }
}

extension AppMigrationDataBuilder: AppMigrationDataBuilding {
    func buildWrapper() -> CompoundOperationWrapper<AppMigrationData> {
        let walletRepository = walletRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchOperation = walletRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )

        let buildOperation = ClosureOperation<AppMigrationData> { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let wallets = try fetchOperation.extractNoCancellableResultData()
            let walletsSet = Set(wallets)

            // Build settings
            let settings = self.buildSettings()

            // Convert to public info
            let publicInfo: Set<CloudBackup.WalletPublicInfo>
            do {
                publicInfo = try self.walletConverter.convertToPublicInfo(from: walletsSet)
            } catch {
                throw AppMigrationDataBuilderError.walletConversionFailed(error)
            }

            // Extract private secrets
            let privateInfo: Set<CloudBackup.DecryptedFileModel.WalletPrivateInfo>
            do {
                privateInfo = try self.walletSecretsExporter.exportSecrets(from: walletsSet)
            } catch {
                throw AppMigrationDataBuilderError.secretsExportFailed(error)
            }

            let walletsData = WalletsData(
                publicInfo: publicInfo,
                privateInfo: privateInfo
            )

            return AppMigrationData(
                version: "1.0",
                migratedAt: UInt64(Date().timeIntervalSince1970),
                settings: settings,
                wallets: walletsData
            )
        }

        buildOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: buildOperation,
            dependencies: [fetchOperation]
        )
    }
}
