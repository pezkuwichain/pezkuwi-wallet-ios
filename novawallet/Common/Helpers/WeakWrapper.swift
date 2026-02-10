import Foundation

final class WeakWrapper {
    weak var target: AnyObject?

    init(target: AnyObject) {
        self.target = target
    }
}

extension Array where Element == WeakWrapper {
    mutating func clearEmptyItems() {
        self = filter { $0.target != nil }
    }
}

final class WeakObserver<T> {
    weak var target: AnyObject?
    let notificationQueue: DispatchQueue
    let closure: (T) -> Void

    init(target: AnyObject, notificationQueue: DispatchQueue, closure: @escaping (T) -> Void) {
        self.target = target
        self.notificationQueue = notificationQueue
        self.closure = closure
    }
}

extension Array where Element == WeakObserver<Void> {
    mutating func clearEmptyItems() {
        self = filter { $0.target != nil }
    }
}
