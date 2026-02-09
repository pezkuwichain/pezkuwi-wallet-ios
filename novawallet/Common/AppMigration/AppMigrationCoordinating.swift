import Foundation

protocol AppMigrationCoordinatorDelegate: AnyObject {
    func appMigrationCoordinatorDidComplete(_ coordinator: AppMigrationCoordinating)
    func appMigrationCoordinator(_ coordinator: AppMigrationCoordinating, didFailWith error: Error)
}

protocol AppMigrationCoordinating: AnyObject {
    var delegate: AppMigrationCoordinatorDelegate? { get set }

    func setup()
    func teardown()
}
