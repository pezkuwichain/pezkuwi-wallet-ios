import Foundation

// MARK: - AppMigrationData

struct AppMigrationData: Codable, Equatable {
    let version: String
    let migratedAt: UInt64
    let settings: [String: CodableValue]
    let wallets: WalletsData
}

// MARK: - CodableValue

enum CodableValue: Codable, Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case data(Data)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Data.self) {
            self = .data(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode CodableValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .data(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    static func from(anyValue: Any?) -> CodableValue? {
        guard let value = anyValue else {
            return .null
        }

        if let boolValue = value as? Bool {
            return .bool(boolValue)
        } else if let intValue = value as? Int {
            return .int(intValue)
        } else if let doubleValue = value as? Double {
            return .double(doubleValue)
        } else if let stringValue = value as? String {
            return .string(stringValue)
        } else if let dataValue = value as? Data {
            return .data(dataValue)
        } else {
            return nil
        }
    }
}

// MARK: - WalletsData

struct WalletsData: Codable, Equatable {
    let publicInfo: Set<CloudBackup.WalletPublicInfo>
    let privateInfo: Set<CloudBackup.DecryptedFileModel.WalletPrivateInfo>
}
