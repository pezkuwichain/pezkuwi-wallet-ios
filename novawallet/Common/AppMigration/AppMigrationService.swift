import Foundation
import Operation_iOS

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
    private var observers: [WeakObserver<AppMigrationMessage>] = []
    private var pendingMessage: AppMigrationMessage?

    private let parser: AppMigrationMessageParser
    private let notificationQueue: DispatchQueue

    private let mutex = NSLock()

    public init(
        localDeepLinkScheme: String,
        queryFactory: AppMigrationQueryFactoryProtocol = AppMigrationDefaultQueryFactory(),
        notificationQueue: DispatchQueue = .init(label: "io.novawallet.appmigrationservice.\(UUID().uuidString)")
    ) {
        parser = AppMigrationMessageParser(
            localDeepLinkScheme: localDeepLinkScheme,
            queryFactory: queryFactory
        )
        self.notificationQueue = notificationQueue
    }
}

// MARK: - Private

private extension AppMigrationService {
    func markPendingMessageConsumed() {
        pendingMessage = nil
    }

    func handle(message: AppMigrationMessage) {
        clearEmptyItems()

        guard !observers.isEmpty else {
            pendingMessage = message
            return
        }

        markPendingMessageConsumed()

        observers.forEach { observer in
            dispatchInQueueWhenPossible(
                observer.notificationQueue,
                block: { observer.closure(message) }
            )
        }
    }

    func clearEmptyItems() {
        observers = observers.filter { $0.target != nil }
    }
}

// MARK: - AppMigrationServiceProtocol

extension AppMigrationService: AppMigrationServiceProtocol {
    public func handle(url: URL) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }

        guard let action = parser.parseAction(from: url) else {
            return false
        }

        if let message = try? parser.parseMessage(for: action, from: url) {
            handle(message: message)
        }

        return true
    }

    public func addObserver(_ observer: AppMigrationObserver) {
        mutex.lock()
        defer { mutex.unlock() }

        clearEmptyItems()

        guard !observers.contains(where: { $0.target === observer }) else { return }

        let weakObserver = WeakObserver(
            target: observer,
            notificationQueue: notificationQueue,
            closure: { observer.didReceiveMigration(message: $0) }
        )

        observers.append(weakObserver)
    }

    public func removeObserver(_ observer: AppMigrationObserver) {
        mutex.lock()
        defer { mutex.unlock() }

        clearEmptyItems()

        observers = observers.filter { $0.target !== observer }
    }

    public func consumePendingMessage() -> AppMigrationMessage? {
        mutex.lock()
        defer { mutex.unlock() }

        let message = pendingMessage

        markPendingMessageConsumed()

        return message
    }
}
