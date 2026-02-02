import Foundation

public protocol AppMigrationDestinationProtocol {
    func accept(with message: AppMigrationMessage.Accepted) throws
}

public final class AppMigrationDestination {
    public let originScheme: String

    let navigator: AppMigrationLinkNavigating
    let queryFactory: AppMigrationQueryFactoryProtocol

    public init(
        originScheme: String,
        queryFactory: AppMigrationQueryFactoryProtocol,
        navigator: AppMigrationLinkNavigating
    ) {
        self.originScheme = originScheme
        self.queryFactory = queryFactory
        self.navigator = navigator
    }
}

private extension AppMigrationDestination {
    func createAcceptedDeepLink(from message: AppMigrationMessage.Accepted) throws -> URL {
        var components = URLComponents()
        components.scheme = originScheme
        components.host = AppMigrationDomain.origin.rawValue
        components.path = "/" + AppMigrationAction.migrateAccepted.rawValue

        components.queryItems = [
            URLQueryItem(
                name: AppMigrationQueryKey.key.rawValue,
                value: queryFactory.stringify(data: message.destinationPublicKey)
            )
        ]

        guard let url = components.url else {
            throw AppMigrationChannelError.invalidParameters
        }

        return url
    }
}

// MARK: - AppMigrationDestinationProtocol

extension AppMigrationDestination: AppMigrationDestinationProtocol {
    public func accept(with message: AppMigrationMessage.Accepted) throws {
        let deepLink = try createAcceptedDeepLink(from: message)
        navigator.open(deepLink)
    }
}
