import Foundation

public protocol AppMigrationQueryFactoryProtocol {
    func stringify(data: Data) -> String
    func data(from string: String) throws -> Data
}

public final class AppMigrationDefaultQueryFactory {
    public init() {}
}

extension AppMigrationDefaultQueryFactory: AppMigrationQueryFactoryProtocol {
    public func stringify(data: Data) -> String { data.toHex() }

    public func data(from string: String) throws -> Data {
        try Data(hexString: string)
    }
}
