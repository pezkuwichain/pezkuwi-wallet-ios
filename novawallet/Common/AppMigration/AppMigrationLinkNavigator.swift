import Foundation
import UIKit.UIApplication

public protocol AppMigrationLinkNavigating {
    func canOpenURL(_ url: URL) -> Bool
    func open(_ url: URL)
}

public final class AppMigrationLinkNavigator {
    let application: UIApplication

    public init(application: UIApplication) {
        self.application = application
    }
}

extension AppMigrationLinkNavigator: AppMigrationLinkNavigating {
    public func canOpenURL(_ url: URL) -> Bool {
        application.canOpenURL(url)
    }

    public func open(_ url: URL) {
        application.open(url)
    }
}
