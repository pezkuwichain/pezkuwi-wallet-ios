import Foundation
import SubstrateSdk

/// The `{visible, txID, raw_data, raw_data_hex}` transaction envelope TronGrid returns from both
/// `/wallet/createtransaction` (top-level) and `/wallet/triggersmartcontract` (nested under a
/// `"transaction"` key) - verified live against Shasta testnet (2026) for both endpoints.
///
/// `rawData` is decoded as the generic `JSON` passthrough type (from the `SubstrateSdk` package,
/// already used elsewhere in this project for opaque JSON payloads, e.g.
/// `GovMetadataOperationFactory`) rather than a dedicated Swift model of Tron's `raw_data` schema.
/// This is deliberate: this app never needs to interpret `raw_data`'s contents (it never builds a
/// Tron `Transaction`/`TransferContract`/`TriggerSmartContract` protobuf message itself - see
/// `TronGridOperationFactory`'s doc comment), only to round-trip it unchanged from
/// `createtransaction`/`triggersmartcontract`'s response back into `broadcasttransaction`'s
/// request body alongside the freshly computed `signature`.
struct TronGridUnsignedTransaction: Codable {
    let visible: Bool?
    let txID: String
    let rawData: JSON
    let rawDataHex: String

    enum CodingKeys: String, CodingKey {
        case visible
        case txID
        case rawData = "raw_data"
        case rawDataHex = "raw_data_hex"
    }
}

/// Response shape of `POST {baseUrl}/wallet/createtransaction`, used to build an unsigned native
/// TRX transfer. Verified live against Shasta testnet (2026):
///   - Success: fields (`visible`, `txID`, `raw_data`, `raw_data_hex`) are all top-level, NOT
///     nested under a `"transaction"` key (unlike `triggersmartcontract` below) - confirmed with a
///     real, currently-activated Shasta account as `owner_address`.
///   - Failure (e.g. `owner_address` never activated on-chain, or `to_address == owner_address`):
///     TronGrid replies HTTP 200 with a body of just `{"Error": "<human-readable message>"}` - no
///     `code`/`txid` fields like `broadcasttransaction`'s error shape (these are two different,
///     independently-verified error envelopes on two different endpoints, not the same shape).
struct TronGridCreateTransactionResponse: Decodable {
    let transaction: TronGridUnsignedTransaction?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case visible, txID, rawData = "raw_data", rawDataHex = "raw_data_hex"
        case error = "Error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let error = try container.decodeIfPresent(String.self, forKey: .error) {
            self.error = error
            transaction = nil
        } else {
            self.error = nil
            transaction = TronGridUnsignedTransaction(
                visible: try container.decodeIfPresent(Bool.self, forKey: .visible),
                txID: try container.decode(String.self, forKey: .txID),
                rawData: try container.decode(JSON.self, forKey: .rawData),
                rawDataHex: try container.decode(String.self, forKey: .rawDataHex)
            )
        }
    }
}

/// Response shape of `POST {baseUrl}/wallet/triggersmartcontract`, used to build an unsigned
/// TRC20 `transfer(address,uint256)` call. Verified live against Shasta testnet (2026) against a
/// currently-active real TRC20 contract: unlike `createtransaction`, the transaction envelope is
/// nested under a `"transaction"` key alongside a `"result": {"result": true}` sibling field.
struct TronGridTriggerSmartContractResponse: Decodable {
    struct ResultInfo: Decodable {
        let result: Bool?
        let message: String?
    }

    let result: ResultInfo
    let transaction: TronGridUnsignedTransaction?
}

/// Request body of `POST {baseUrl}/wallet/broadcasttransaction`: the exact `TronGridUnsignedTransaction`
/// envelope as received from `createtransaction`/`triggersmartcontract`, round-tripped unchanged,
/// plus the freshly computed signature. Field name/shape (`signature` as an array of hex strings)
/// verified live against Shasta testnet (2026) - an intentionally-invalid dummy signature was
/// submitted in this exact shape and TronGrid replied with a `SIGERROR`-coded response (see
/// `TronGridBroadcastResponse` below), proving the request envelope itself was well-formed and
/// parsed correctly up to the signature-validation stage.
struct TronGridBroadcastRequest: Encodable {
    let visible: Bool?
    let txID: String
    let rawData: JSON
    let rawDataHex: String
    let signature: [String]

    enum CodingKeys: String, CodingKey {
        case visible
        case txID
        case rawData = "raw_data"
        case rawDataHex = "raw_data_hex"
        case signature
    }

    init(transaction: TronGridUnsignedTransaction, signatureHex: String) {
        visible = transaction.visible
        txID = transaction.txID
        rawData = transaction.rawData
        rawDataHex = transaction.rawDataHex
        signature = [signatureHex]
    }
}

/// Response shape of `POST {baseUrl}/wallet/broadcasttransaction`.
///
/// The FAILURE path was verified live against Shasta testnet (2026): broadcasting a real,
/// well-formed transaction envelope (built via a real `createtransaction` call against a real
/// active account) with a deliberately-invalid dummy signature returned exactly
/// `{"code": "SIGERROR", "txid": "<txID>", "message": "<hex-encoded error string>"}` - `result`
/// was absent entirely (not `false`) on this failure path.
///
/// The SUCCESS path (`{"result": true, "txid": "<txID>"}`) is NOT independently live-verified by
/// this app - it could not be produced without a funded, self-controlled Shasta testnet account
/// (blocked by the faucet's Cloudflare Turnstile captcha in this environment - see PR notes). It
/// matches TronGrid's official published API reference, so is used as a best-effort shape based on
/// documentation, not on an observed live response. Both `result` and `code`/`message` are
/// decoded as optional so a successful broadcast doesn't fail to decode.
struct TronGridBroadcastResponse: Decodable {
    let result: Bool?
    let txid: String?
    let code: String?
    let message: String?

    var isSuccess: Bool {
        result == true
    }

    /// `message` is hex-encoded (verified live: the real `SIGERROR` response's `message` field
    /// decoded via UTF8-from-hex to the human-readable
    /// "Validate signature error: java.lang.IllegalArgumentException: Invalid point compression").
    var decodedMessage: String? {
        guard let message, let data = try? Data(hexString: message) else {
            return message
        }

        return String(data: data, encoding: .utf8) ?? message
    }
}

/// Response shape of `POST {baseUrl}/wallet/getaccountresource` (equivalently `getaccountnet` for
/// the bandwidth-only subset of these same fields), verified live against Shasta testnet (2026)
/// for a real, currently-active account. Mirrors `TronGridAccountResponse`'s "absent means zero"
/// convention (confirmed live: an account that hasn't consumed any bandwidth/energy this window
/// omits the corresponding `...Used` field entirely rather than sending `0`).
struct TronGridAccountResourceResponse: Decodable {
    let freeNetLimit: Int?
    let freeNetUsed: Int?
    let netLimit: Int?
    let netUsed: Int?
    let energyLimit: Int?
    let energyUsed: Int?

    enum CodingKeys: String, CodingKey {
        case freeNetLimit
        case freeNetUsed
        case netLimit = "NetLimit"
        case netUsed = "NetUsed"
        case energyLimit = "EnergyLimit"
        case energyUsed = "EnergyUsed"
    }

    /// Total bytes of bandwidth still available before TRX starts being burned for the `NET`
    /// resource: (free daily allotment - free used) + (staked allotment - staked used), each
    /// individually floored at 0 before summing.
    var availableBandwidthInBytes: Int {
        let freeAvailable = max(0, (freeNetLimit ?? 0) - (freeNetUsed ?? 0))
        let stakedAvailable = max(0, (netLimit ?? 0) - (netUsed ?? 0))
        return freeAvailable + stakedAvailable
    }

    /// Same shape of calculation for the `ENERGY` resource (relevant to TRC20/smart-contract
    /// calls only - plain TRX transfers don't consume energy).
    var availableEnergy: Int {
        max(0, (energyLimit ?? 0) - (energyUsed ?? 0))
    }
}

/// Response shape of `POST {baseUrl}/wallet/getchainparameters`, verified live against Shasta
/// testnet (2026): a flat `{"chainParameter": [{"key": "...", "value": <int, optional>}, ...]}`
/// array. `value` is confirmed absent (not `0`) for several boolean-style flag keys that happen to
/// be off (e.g. `getAllowUpdateAccountName` had no `value` key at all in the live response) -
/// decoded as optional accordingly.
struct TronGridChainParametersResponse: Decodable {
    struct Parameter: Decodable {
        let key: String
        let value: Int?
    }

    let chainParameter: [Parameter]

    func value(forKey key: String) -> Int? {
        chainParameter.first { $0.key == key }?.value
    }

    /// Sun burned per byte of bandwidth consumed beyond the sender's free/staked allotment.
    /// Live-confirmed key name and a value of `1000` on Shasta testnet (2026).
    var transactionFeePerByte: Int? {
        value(forKey: "getTransactionFee")
    }

    /// Sun burned per unit of TVM energy consumed beyond the sender's staked allotment.
    /// Live-confirmed key name and a value of `100` on Shasta testnet (2026).
    var energyFeePerUnit: Int? {
        value(forKey: "getEnergyFee")
    }
}
