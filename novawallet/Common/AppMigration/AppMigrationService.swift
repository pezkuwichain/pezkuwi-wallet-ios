import Foundation

public protocol AppMigrationObserver: AnyObject {
    func didReceiveMigration(message: AppMigrationMessage)
}

public protocol AppMigrationServiceProtocol {
    func addObserver(_ observer: AppMigrationObserver)
    func removeObserver(_ observer: AppMigrationObserver)

    func consumePendingMessage() -> AppMigrationMessage?

    func handle(url: URL) -> Bool
}

public final class AppMigrationService {
    private var observers: [WeakWrapper] = []
    private var pendingMessage: AppMigrationMessage?

    private let parser: AppMigrationMessageParser

    public init(
        localDeepLinkScheme: String,
        queryFactory: AppMigrationQueryFactoryProtocol = AppMigrationDefaultQueryFactory()
    ) {
        parser = AppMigrationMessageParser(
            localDeepLinkScheme: localDeepLinkScheme,
            queryFactory: queryFactory
        )
    }
}

// MARK: - Private

private extension AppMigrationService {
    func markPendingMessageConsumed() {
        pendingMessage = nil
    }

    func handle(message: AppMigrationMessage) {
        observers.clearEmptyItems()

        if !observers.isEmpty {
            markPendingMessageConsumed()

            observers.forEach {
                ($0.target as? AppMigrationObserver)?.didReceiveMigration(message: message)
            }
        } else {
            pendingMessage = message
        }
    }
}

// MARK: - AppMigrationServiceProtocol

extension AppMigrationService: AppMigrationServiceProtocol {
    public func handle(url: URL) -> Bool {
        guard let action = parser.parseAction(from: url) else {
            return false
        }

        if let message = try? parser.parseMessage(for: action, from: url) {
            handle(message: message)
        }

        return true
    }

    public func addObserver(_ observer: AppMigrationObserver) {
        observers.clearEmptyItems()

        if !observers.contains(where: { $0.target === observer }) {
            observers.append(.init(target: observer))
        }
    }

    public func removeObserver(_ observer: AppMigrationObserver) {
        observers.clearEmptyItems()

        observers = observers.filter { $0.target !== observer }
    }

    public func consumePendingMessage() -> AppMigrationMessage? {
        let message = pendingMessage

        markPendingMessageConsumed()

        return message
    }
}
