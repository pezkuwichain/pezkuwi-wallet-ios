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

    private enum TypeTag: String, Codable {
        case bool
        case int
        case double
        case string
        case data
        case null
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeTag.self, forKey: .type)

        switch type {
        case .bool:
            let value = try container.decode(Bool.self, forKey: .value)
            self = .bool(value)
        case .int:
            let value = try container.decode(Int.self, forKey: .value)
            self = .int(value)
        case .double:
            let value = try container.decode(Double.self, forKey: .value)
            self = .double(value)
        case .string:
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case .data:
            let value = try container.decode(Data.self, forKey: .value)
            self = .data(value)
        case .null:
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .bool(value):
            try container.encode(TypeTag.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .int(value):
            try container.encode(TypeTag.int, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .double(value):
            try container.encode(TypeTag.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .string(value):
            try container.encode(TypeTag.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .data(value):
            try container.encode(TypeTag.data, forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode(TypeTag.null, forKey: .type)
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
