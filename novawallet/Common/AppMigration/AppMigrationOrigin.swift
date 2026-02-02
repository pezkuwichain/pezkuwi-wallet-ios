import UIKit

public protocol AppMigrationOriginProtocol {
    func start(with message: AppMigrationMessage.Start) throws
    func complete(with message: AppMigrationMessage.Complete) throws
}

public final class AppMigrationOrigin {
    let navigator: AppMigrationLinkNavigating
    let queryFactory: AppMigrationQueryFactoryProtocol

    public let config: AppMigrationRemoteConfig

    public init(
        config: AppMigrationRemoteConfig,
        queryFactory: AppMigrationQueryFactoryProtocol,
        navigator: AppMigrationLinkNavigating
    ) {
        self.config = config
        self.queryFactory = queryFactory
        self.navigator = navigator
    }
}

private extension AppMigrationOrigin {
    func createStartAppLink(for message: AppMigrationMessage.Start) throws -> URL {
        guard var components = URLComponents(
            url: config.destinationAppLinkURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw AppMigrationChannelError.invalidDestinationURL
        }

        components.queryItems = [
            URLQueryItem(
                name: AppMigrationQueryKey.action.rawValue,
                value: AppMigrationAction.migrate.rawValue
            ),
            URLQueryItem(
                name: AppMigrationQueryKey.scheme.rawValue,
                value: message.originScheme
            )
        ]

        guard let url = components.url else {
            throw AppMigrationChannelError.invalidParameters
        }

        return url
    }

    func createStartDeepLink(for message: AppMigrationMessage.Start) throws -> URL {
        var components = URLComponents()
        components.scheme = config.destinationScheme
        components.host = AppMigrationDomain.destination.rawValue
        components.path = "/" + AppMigrationAction.migrate.rawValue

        components.queryItems = [
            URLQueryItem(
                name: AppMigrationQueryKey.scheme.rawValue,
                value: message.originScheme
            )
        ]

        guard let url = components.url else {
            throw AppMigrationChannelError.invalidParameters
        }

        return url
    }

    func createCompleteDeepLink(for message: AppMigrationMessage.Complete) throws -> URL {
        var components = URLComponents()
        components.scheme = config.destinationScheme
        components.host = AppMigrationDomain.destination.rawValue
        components.path = "/" + AppMigrationAction.migrateComplete.rawValue

        components.queryItems = [
            URLQueryItem(
                name: AppMigrationQueryKey.key.rawValue,
                value: queryFactory.stringify(data: message.originPublicKey)
            ),
            URLQueryItem(
                name: AppMigrationQueryKey.encryptedData.rawValue,
                value: queryFactory.stringify(data: message.encryptedData)
            )
        ]

        guard let url = components.url else {
            throw AppMigrationChannelError.invalidParameters
        }

        return url
    }
}

// MARK: - AppMigrationOriginProtocol

extension AppMigrationOrigin: AppMigrationOriginProtocol {
    public func start(with message: AppMigrationMessage.Start) throws {
        // Prefer deep link if New App is installed
        let deepLink = try createStartDeepLink(for: message)

        guard !navigator.canOpenURL(deepLink) else {
            navigator.open(deepLink)
            return
        }

        let appLink = try createStartAppLink(for: message)
        navigator.open(appLink)
    }

    public func complete(with message: AppMigrationMessage.Complete) throws {
        let deepLink = try createCompleteDeepLink(for: message)
        navigator.open(deepLink)
    }
}
