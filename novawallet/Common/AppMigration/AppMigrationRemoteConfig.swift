import Foundation

public struct AppMigrationRemoteConfig: Codable, Equatable {
    public let destinationAppLinkURL: URL
    public let destinationScheme: String
    public let originScheme: String

    public init(
        destinationAppLinkURL: URL,
        destinationScheme: String,
        originScheme: String
    ) {
        self.destinationAppLinkURL = destinationAppLinkURL
        self.destinationScheme = destinationScheme
        self.originScheme = originScheme
    }
}

public extension AppMigrationRemoteConfig {
    func canOpenDestinationApp(using navigator: AppMigrationLinkNavigating) -> Bool {
        var components = URLComponents()
        components.scheme = destinationScheme
        components.host = AppMigrationDomain.destination.rawValue

        guard let url = components.url else {
            return false
        }

        return navigator.canOpenURL(url)
    }
}
