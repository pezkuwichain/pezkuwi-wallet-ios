import Foundation
import Keystore_iOS
import SubstrateSdk
import Operation_iOS

protocol AppMigrationDataBuilding {
    func build() throws -> AppMigrationData
}

enum AppMigrationDataBuilderError: Error {
    case failedToBuildSettings
    case failedToBuildWallets(Error)
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
        var settings: [String: CodableValue] = [:]

        for settingsKey in SettingsKey.allCases {
            let key = settingsKey.rawValue

            if let anyValue = settingsManager.anyValue(for: key) {
                if let codableValue = CodableValue.from(anyValue: anyValue) {
                    settings[key] = codableValue
                }
            }
        }

        return settings
    }

    private func buildWallets() throws -> WalletsData {
        // Create repository for fetching all wallets
        let walletRepository = walletRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // Fetch all wallets from repository
        let wallets = try walletRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        ).extractNoCancellableResultData()

        let walletsSet = Set(wallets)

        // Convert to public info
        let publicInfo = try walletConverter.convertToPublicInfo(from: walletsSet)

        // Extract private secrets
        let privateInfo = try walletSecretsExporter.exportSecrets(from: walletsSet)

        return WalletsData(
            publicInfo: publicInfo,
            privateInfo: privateInfo
        )
    }
}

extension AppMigrationDataBuilder: AppMigrationDataBuilding {
    func build() throws -> AppMigrationData {
        let settings = buildSettings()
        let wallets = try buildWallets()

        return AppMigrationData(
            version: "1.0",
            migratedAt: UInt64(Date().timeIntervalSince1970),
            settings: settings,
            wallets: wallets
        )
    }
}
