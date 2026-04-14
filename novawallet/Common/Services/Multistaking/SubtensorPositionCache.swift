import Foundation
import BigInt
import xxHash_Swift

/// Shared per-coldkey cache of Bittensor stake positions.
///
/// Background: `MultistakingSyncService` creates one `OnchainSyncServiceProtocol`
/// instance per (ChainAsset, StakingType) pair. For Bittensor that means 129
/// services fire concurrently (TAO root + 128 subnet alpha assets) the moment a
/// wallet is selected. If each service independently queries the Bittensor RPC
/// endpoint, the public node (entrypoint-finney.opentensor.ai) rate-limits us
/// and most services return nil — which was why root-staking positions were
/// invisible on the dashboard.
///
/// This actor ensures only one fetch is in flight per coldkey: the first
/// service initiates a full "hotkeys + alpha across all netuids + enrichment"
/// fetch, and the other 128 await the same result. Results are cached briefly
/// (15s) so follow-up sync cycles reuse the same payload.
actor SubtensorPositionCache {
    static let shared = SubtensorPositionCache()

    struct Position {
        let hotkey: AccountId
        let netuid: UInt16
        /// Actual alpha amount in smallest units (RAO for netuid=0, alpha-unit for netuid>0)
        let amount: BigUInt
    }

    private struct CacheEntry {
        let positions: [Position]
        let expiry: Date
    }

    private var cache: [Data: CacheEntry] = [:]
    private var inFlight: [Data: Task<[Position], Error>] = [:]

    private static let ttl: TimeInterval = 15

    /// Fetch positions for a coldkey. If a fetch is already in flight for this
    /// coldkey, await the same task. Otherwise start a new fetch and cache it.
    func positions(for coldkey: AccountId, rpcURL: URL) async throws -> [Position] {
        if let entry = cache[coldkey], entry.expiry > Date() {
            return entry.positions
        }

        if let task = inFlight[coldkey] {
            return try await task.value
        }

        let task = Task<[Position], Error> {
            try await Self.fetchAllPositions(coldkey: coldkey, rpcURL: rpcURL)
        }
        inFlight[coldkey] = task

        do {
            let result = try await task.value
            cache[coldkey] = CacheEntry(
                positions: result,
                expiry: Date().addingTimeInterval(Self.ttl)
            )
            inFlight[coldkey] = nil
            return result
        } catch {
            inFlight[coldkey] = nil
            throw error
        }
    }

    /// Invalidate the cache — called after a stake/unstake extrinsic so the
    /// next sync reflects the new state immediately.
    func invalidate(coldkey: AccountId) {
        cache[coldkey] = nil
        inFlight[coldkey]?.cancel()
        inFlight[coldkey] = nil
    }

    // MARK: - Fetch implementation

    //
    // Mirrors `SubtensorPositionFetcher` in Modules/Staking/SubtensorStaking/,
    // but duplicated here because Common/ cannot depend on Modules/. The two
    // implementations must stay in sync on storage keys and SCALE decoding.

    private static func fetchAllPositions(coldkey: AccountId, rpcURL: URL) async throws -> [Position] {
        // Step 1: hotkeys for this coldkey
        let hkKey = stakingHotkeysKey(coldkey: coldkey)
        let hkResults = try await sendBatchChunked(
            requests: [rpcRequest(id: 0, key: hkKey)],
            url: rpcURL
        )
        guard let hkHex = hkResults[0] ?? nil else { return [] }
        let hotkeys = decodeVecAccountId(hex: hkHex)
        guard !hotkeys.isEmpty else { return [] }

        // Step 2: Alpha(hotkey, coldkey, netuid) for every netuid 0–128.
        var alphaRequests: [[String: Any]] = []
        var alphaIdToKey: [Int: (AccountId, UInt16)] = [:]
        var reqId = 0

        for hotkey in hotkeys {
            for netuid in UInt16(0) ... UInt16(128) {
                let key = alphaKey(hotkey: hotkey, coldkey: coldkey, netuid: netuid)
                alphaRequests.append(rpcRequest(id: reqId, key: key))
                alphaIdToKey[reqId] = (hotkey, netuid)
                reqId += 1
            }
        }

        let alphaResponses = try await sendBatchChunked(requests: alphaRequests, url: rpcURL)

        var nonZero: [(hotkey: AccountId, netuid: UInt16, shares: BigUInt)] = []
        for (id, meta) in alphaIdToKey {
            let shares = decodeU128LE(hex: alphaResponses[id] ?? nil)
            if shares > 0 {
                nonZero.append((meta.0, meta.1, shares))
            }
        }
        guard !nonZero.isEmpty else { return [] }

        // Step 3: enrich with TotalHotkeyAlpha + TotalHotkeyShares for each
        // (hotkey, netuid) that had non-zero shares.
        struct HotkeyNetuid: Hashable {
            let hotkey: AccountId
            let netuid: UInt16
        }
        enum EnrichKind { case totalAlpha, totalShares }

        let uniquePairs = Set(nonZero.map { HotkeyNetuid(hotkey: $0.hotkey, netuid: $0.netuid) })
        var enrichRequests: [[String: Any]] = []
        var enrichIdToMeta: [Int: (HotkeyNetuid, EnrichKind)] = [:]
        var enrichId = 0

        for pair in uniquePairs {
            enrichRequests.append(
                rpcRequest(id: enrichId, key: totalHotkeyAlphaKey(hotkey: pair.hotkey, netuid: pair.netuid))
            )
            enrichIdToMeta[enrichId] = (pair, .totalAlpha)
            enrichId += 1
            enrichRequests.append(
                rpcRequest(id: enrichId, key: totalHotkeySharesKey(hotkey: pair.hotkey, netuid: pair.netuid))
            )
            enrichIdToMeta[enrichId] = (pair, .totalShares)
            enrichId += 1
        }

        let enrichResponses = try await sendBatchChunked(requests: enrichRequests, url: rpcURL)

        var totalAlphaMap: [HotkeyNetuid: BigUInt] = [:]
        var totalSharesMap: [HotkeyNetuid: BigUInt] = [:]

        for (id, meta) in enrichIdToMeta {
            switch meta.1 {
            case .totalAlpha:
                totalAlphaMap[meta.0] = decodeU64LE(hex: enrichResponses[id] ?? nil).map { BigUInt($0) } ?? .zero
            case .totalShares:
                totalSharesMap[meta.0] = decodeU128LE(hex: enrichResponses[id] ?? nil)
            }
        }

        return nonZero.compactMap { pos -> Position? in
            let key = HotkeyNetuid(hotkey: pos.hotkey, netuid: pos.netuid)
            let tha = totalAlphaMap[key] ?? .zero
            let ths = totalSharesMap[key] ?? .zero
            guard ths > 0 else { return nil }
            let amount = (pos.shares * tha) / ths
            guard amount > 0 else { return nil }
            return Position(hotkey: pos.hotkey, netuid: pos.netuid, amount: amount)
        }
    }

    // MARK: - Storage key builders

    private static func stakingHotkeysKey(coldkey: AccountId) -> String {
        let prefix = twox128(b("SubtensorModule")) + twox128(b("StakingHotkeys"))
        return hex(prefix + blake2_128(coldkey) + coldkey)
    }

    private static func alphaKey(hotkey: AccountId, coldkey: AccountId, netuid: UInt16) -> String {
        let prefix = twox128(b("SubtensorModule")) + twox128(b("Alpha"))
        let k1 = blake2_128(hotkey) + hotkey
        let k2 = blake2_128(coldkey) + coldkey
        let k3 = netuidLE(netuid)
        return hex(prefix + k1 + k2 + k3)
    }

    private static func totalHotkeyAlphaKey(hotkey: AccountId, netuid: UInt16) -> String {
        let prefix = twox128(b("SubtensorModule")) + twox128(b("TotalHotkeyAlpha"))
        let k1 = blake2_128(hotkey) + hotkey
        let k2 = netuidLE(netuid)
        return hex(prefix + k1 + k2)
    }

    private static func totalHotkeySharesKey(hotkey: AccountId, netuid: UInt16) -> String {
        let prefix = twox128(b("SubtensorModule")) + twox128(b("TotalHotkeyShares"))
        let k1 = blake2_128(hotkey) + hotkey
        let k2 = netuidLE(netuid)
        return hex(prefix + k1 + k2)
    }

    private static func b(_ str: String) -> Data { str.data(using: .utf8)! }

    private static func hex(_ data: Data) -> String {
        "0x" + data.map { String(format: "%02x", $0) }.joined()
    }

    private static func twox128(_ data: Data) -> Data {
        var h0 = XXH64.digest(data, seed: 0)
        var h1 = XXH64.digest(data, seed: 1)
        return Data(bytes: &h0, count: 8) + Data(bytes: &h1, count: 8)
    }

    private static func blake2_128(_ data: Data) -> Data {
        (try? data.blake2b16()) ?? Data(count: 16)
    }

    private static func netuidLE(_ netuid: UInt16) -> Data {
        Data([UInt8(netuid & 0xFF), UInt8(netuid >> 8)])
    }

    // MARK: - SCALE decoders

    private static func decodeVecAccountId(hex: String) -> [AccountId] {
        let bytes = hexBytes(hex)
        guard !bytes.isEmpty, let (count, offset) = compactInt(bytes) else { return [] }
        let size = 32
        guard offset + Int(count) * size <= bytes.count else { return [] }
        var result: [AccountId] = []
        var pos = offset
        for _ in 0 ..< Int(count) {
            result.append(Data(bytes[pos ..< pos + size]))
            pos += size
        }
        return result
    }

    private static func decodeU64LE(hex: String?) -> UInt64? {
        guard let hex else { return nil }
        let bytes = hexBytes(hex)
        guard bytes.count >= 8 else { return nil }
        return bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt64.self) }
    }

    private static func decodeU128LE(hex: String?) -> BigUInt {
        guard let hex else { return 0 }
        let bytes = hexBytes(hex)
        guard bytes.count >= 16 else { return 0 }
        return BigUInt(Data(bytes.prefix(16).reversed()))
    }

    private static func hexBytes(_ hex: String) -> [UInt8] {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var bytes: [UInt8] = []
        var idx = clean.startIndex
        while let end = clean.index(idx, offsetBy: 2, limitedBy: clean.endIndex),
              end != idx {
            bytes.append(UInt8(clean[idx ..< end], radix: 16) ?? 0)
            idx = end
        }
        return bytes
    }

    private static func compactInt(_ bytes: [UInt8]) -> (UInt64, Int)? {
        guard !bytes.isEmpty else { return nil }
        switch bytes[0] & 0x03 {
        case 0x00:
            return (UInt64(bytes[0] >> 2), 1)
        case 0x01:
            guard bytes.count >= 2 else { return nil }
            return (UInt64((UInt16(bytes[0]) | UInt16(bytes[1]) << 8) >> 2), 2)
        case 0x02:
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 |
                UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return (UInt64(raw >> 2), 4)
        default:
            return nil
        }
    }

    // MARK: - RPC transport

    private static func rpcRequest(id: Int, key: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "method": "state_getStorage", "params": [key]]
    }

    private static func sendBatchChunked(requests: [[String: Any]], url: URL) async throws -> [Int: String?] {
        let chunkSize = 500
        var combined: [Int: String?] = [:]
        var offset = 0
        while offset < requests.count {
            let chunk = Array(requests[offset ..< min(offset + chunkSize, requests.count)])
            let partial = try await sendBatch(requests: chunk, url: url)
            for (key, val) in partial { combined[key] = val }
            offset += chunkSize
        }
        return combined
    }

    private static func sendBatch(requests: [[String: Any]], url: URL) async throws -> [Int: String?] {
        let body = try JSONSerialization.data(withJSONObject: requests)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SubtensorCacheError.invalidResponse
        }

        if let single = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = single["id"] as? Int {
            return [id: single["result"] as? String]
        }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SubtensorCacheError.invalidResponse
        }

        var results: [Int: String?] = [:]
        for item in array {
            guard let id = item["id"] as? Int else { continue }
            results[id] = item["result"] as? String
        }
        return results
    }
}

private enum SubtensorCacheError: Error {
    case invalidResponse
}
