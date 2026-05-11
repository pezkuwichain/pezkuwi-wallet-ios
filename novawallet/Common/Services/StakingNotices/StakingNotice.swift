import Foundation

struct StakingNotice: Equatable {
    enum Severity: String, Decodable, Equatable {
        case info
        case critical
    }

    let chainId: ChainModel.Id
    let severity: Severity
    let shortText: String
    let longText: String
    let endDate: Date?
}

/// Decodes a single notice from the JSON document `nova-utils/notices/staking_notices.json`.
///
/// v1 schema accepts `shortText` / `longText` as plain strings.
/// v2 will accept locale-map objects (`{"en": "...", "ru": "..."}`); the decoder below is written
/// to tolerate either shape so v2 publishes do not break v1 clients. v1 falls back to `en`.
extension StakingNotice: Decodable {
    private enum CodingKeys: String, CodingKey {
        case chainId
        case severity
        case shortText
        case longText
        case endDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        chainId = try container.decode(ChainModel.Id.self, forKey: .chainId)
        severity = try container.decode(Severity.self, forKey: .severity)
        shortText = try Self.decodeLocalized(container: container, key: .shortText)
        longText = try Self.decodeLocalized(container: container, key: .longText)

        if let endDateString = try container.decodeIfPresent(String.self, forKey: .endDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            guard let date = formatter.date(from: endDateString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .endDate,
                    in: container,
                    debugDescription: "Expected ISO-8601 date (YYYY-MM-DD), got \(endDateString)"
                )
            }
            endDate = date
        } else {
            endDate = nil
        }
    }

    private static func decodeLocalized(
        container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> String {
        if let plain = try? container.decode(String.self, forKey: key) {
            return plain
        }
        let localeMap = try container.decode([String: String].self, forKey: key)
        if let englishValue = localeMap["en"] {
            return englishValue
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Locale map for \(key.rawValue) lacks a fallback 'en' entry"
        )
    }
}
