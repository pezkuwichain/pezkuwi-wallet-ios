import Foundation
import BigInt

// Response shape of `POST {baseUrl}/wallet/triggerconstantcontract` on TronGrid's public REST API,
// used here only for the read-only `balanceOf(address)` TRC20 call (never for a state-changing
// contract call - Phase 1 is read-only, no transaction broadcast).
//
// Verified against the live API during implementation (2026) with a real `balanceOf(address)` call
// for the USDT-TRC20 contract shipped in this app's chain config: TronGrid echoed back the exact
// standard Solidity 4-byte selector `70a08231` (== keccak256("balanceOf(address)")[:4], a public,
// well-known constant - not computed by this app, just relied upon) concatenated with this app's
// 32-byte zero-padded `parameter` field in the `transaction.raw_data.contract[0].parameter.value.data`
// echo, confirming the request shape below is correctly interpreted by TronGrid.
struct TronGridTriggerConstantContractResponse: Decodable {
    struct ResultInfo: Decodable {
        let result: Bool?
        let message: String?
    }

    let result: ResultInfo
    // Each entry is a 64-hex-char (32-byte) ABI-encoded word, no "0x" prefix.
    let constantResult: [String]

    enum CodingKeys: String, CodingKey {
        case result
        case constantResult = "constant_result"
    }

    var balance: BigUInt {
        guard let hex = constantResult.first, let value = BigUInt.fromHexString(hex) else {
            return 0
        }

        return value
    }
}
