import UIKit

public enum AppMigrationFactory {
    // MARK: - Origin

    public static func createOrigin(
        config: AppMigrationRemoteConfig,
        application: UIApplication = .shared
    ) -> AppMigrationOrigin {
        let queryFactory = AppMigrationDefaultQueryFactory()
        let navigator = AppMigrationLinkNavigator(application: application)

        return AppMigrationOrigin(
            config: config,
            queryFactory: queryFactory,
            navigator: navigator
        )
    }

    public static func createOriginService(
        config: AppMigrationRemoteConfig
    ) -> AppMigrationService {
        AppMigrationService(
            localDeepLinkScheme: config.originScheme,
            queryFactory: AppMigrationDefaultQueryFactory()
        )
    }

    // MARK: - Destination

    public static func createDestination(
        originScheme: String,
        application: UIApplication = .shared
    ) -> AppMigrationDestination {
        let queryFactory = AppMigrationDefaultQueryFactory()
        let navigator = AppMigrationLinkNavigator(application: application)

        return AppMigrationDestination(
            originScheme: originScheme,
            queryFactory: queryFactory,
            navigator: navigator
        )
    }

    public static func createDestinationService(
        localDeepLinkScheme: String
    ) -> AppMigrationService {
        AppMigrationService(
            localDeepLinkScheme: localDeepLinkScheme,
            queryFactory: AppMigrationDefaultQueryFactory()
        )
    }
}
