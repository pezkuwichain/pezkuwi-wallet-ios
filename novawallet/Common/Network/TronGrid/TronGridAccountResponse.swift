import Foundation
import BigInt

// Response shape of `GET {baseUrl}/v1/accounts/{address}` on TronGrid's public REST API.
// Verified against the live API during implementation (2026): querying a real, currently-unfunded
// address returns `"data":[]` with `"success":true` (no error) and no `balance` key at all for an
// activated-but-zero-TRX account, so `balance` must be treated as optional/absent-means-zero, not
// as a required field. Querying an activated address with the standard BIP39 test mnemonic's
// derived Tron address (`m/44'/195'/0'/0/0`) confirmed the `data[0].address` hex field matches
// `0x41` + this app's own derived 20-byte account id exactly.
struct TronGridAccountResponse: Decodable {
    struct AccountData: Decodable {
        // TRX balance in SUN (1 TRX = 1_000_000 SUN, matching the chain config's `precision: 6`
        // for the native asset). Absent from the JSON entirely when zero. Decoded as a plain
        // `UInt64` (TronGrid returns a bare JSON integer, not a string) - `BigUInt` does not
        // itself conform to `Decodable` in this project's BigInt package, and TRX's max supply
        // comfortably fits in `UInt64` (~1.45e17 SUN at 6 decimals vs a ~1.8e19 UInt64 ceiling).
        let balance: UInt64?
    }

    let data: [AccountData]
    let success: Bool

    var trxBalance: BigUInt {
        BigUInt(data.first?.balance ?? 0)
    }
}
