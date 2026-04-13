import Foundation
import BigInt
import SubstrateSdk
import xxHash_Swift

/// Queries Bittensor chain storage to discover a coldkey's stake positions
/// across all hotkeys and netuids.
///
/// Storage items used (confirmed against live metadata 2026-04-13):
///   - StakingHotkeys(coldkey)          → Vec<AccountId>   hasher: Blake2_128Concat
///   - Alpha(hotkey, coldkey, netuid)   → U128 shares      hashers: B128C, B128C, Identity
///   - TotalHotkeyAlpha(hotkey, netuid) → u64              hashers: B128C, Identity
///   - TotalHotkeyShares(hotkey,netuid) → U128             hashers: B128C, Identity
///
/// Actual alpha = (alpha_shares × total_hotkey_alpha) / total_hotkey_shares
actor SubtensorPositionFetcher {
    enum FetchError: Error {
        case invalidResponse
        case rpcError(String)
    }

    private static let rpcURL = URL(string: "https://entrypoint-finney.opentensor.ai")!

    // Max netuids to scan per hotkey. Covers all current Bittensor subnets.
    static let scannedNetuids: [UInt16] = Array(0 ... 128)

    // MARK: - Public API

    /// Returns all non-zero stake positions for `coldkey` across all hotkeys
    /// and netuids 0–128.
    static func fetchPositions(coldkey: AccountId) async throws -> [SubtensorRawPosition] {
        // Step 1 – which hotkeys does this coldkey delegate to?
        let hotkeys = try await fetchStakingHotkeys(coldkey: coldkey)
        guard !hotkeys.isEmpty else { return [] }

        // Step 2 – batch-query Alpha shares for every (hotkey, coldkey, netuid)
        let shareMap = try await fetchAlphaShares(hotkeys: hotkeys, coldkey: coldkey)

        // Keep only non-zero shares
        let nonZero = shareMap.filter { $0.value > 0 }
        guard !nonZero.isEmpty else { return [] }

        // Step 3 – batch-query TotalHotkeyAlpha + TotalHotkeyShares for the non-zero positions
        let enriched = try await enrichPositions(
            positions: nonZero.map { (hotkey: $0.key.hotkey, netuid: $0.key.netuid, shares: $0.value) },
            hotkeys: hotkeys
        )

        return enriched
    }

    // MARK: - Step 1: StakingHotkeys

    static func fetchStakingHotkeys(coldkey: AccountId) async throws -> [AccountId] {
        let key = stakingHotkeysKey(coldkey: coldkey)
        let requests = [rpcRequest(id: 0, method: "state_getStorage", params: [key])]
        let responses = try await sendBatchRPC(requests: requests)
        guard let hex = responses[0] ?? nil else { return [] }
        return decodeVecAccountId(hex: hex)
    }

    // MARK: - Step 2: Alpha shares

    private struct PositionKey: Hashable {
        let hotkey: AccountId
        let netuid: UInt16
    }

    private static func fetchAlphaShares(
        hotkeys: [AccountId],
        coldkey: AccountId
    ) async throws -> [PositionKey: BigUInt] {
        var requests: [[String: Any]] = []
        var idToKey: [Int: PositionKey] = [:]
        var reqId = 0

        for hotkey in hotkeys {
            for netuid in scannedNetuids {
                let key = alphaKey(hotkey: hotkey, coldkey: coldkey, netuid: netuid)
                requests.append(rpcRequest(id: reqId, method: "state_getStorage", params: [key]))
                idToKey[reqId] = PositionKey(hotkey: hotkey, netuid: netuid)
                reqId += 1
            }
        }

        let responses = try await sendBatchRPCChunked(requests: requests)

        var result: [PositionKey: BigUInt] = [:]
        for (id, posKey) in idToKey {
            let amount = decodeU128LE(hex: responses[id] ?? nil)
            if amount > 0 {
                result[posKey] = amount
            }
        }
        return result
    }

    // MARK: - Step 3: Enrich with TotalHotkeyAlpha / TotalHotkeyShares

    private static func enrichPositions(
        positions: [(hotkey: AccountId, netuid: UInt16, shares: BigUInt)],
        hotkeys _: [AccountId]
    ) async throws -> [SubtensorRawPosition] {
        // Collect unique (hotkey, netuid) pairs that need enrichment
        let uniquePairs = Set(positions.map { PositionKey(hotkey: $0.hotkey, netuid: $0.netuid) })

        var requests: [[String: Any]] = []
        var idToMeta: [Int: (posKey: PositionKey, kind: EnrichKind)] = [:]
        var reqId = 0

        enum EnrichKind { case totalAlpha, totalShares }

        for pair in uniquePairs {
            let alphaKey = totalHotkeyAlphaKey(hotkey: pair.hotkey, netuid: pair.netuid)
            let sharesKey = totalHotkeySharesKey(hotkey: pair.hotkey, netuid: pair.netuid)
            requests.append(rpcRequest(id: reqId, method: "state_getStorage", params: [alphaKey]))
            idToMeta[reqId] = (pair, .totalAlpha)
            reqId += 1
            requests.append(rpcRequest(id: reqId, method: "state_getStorage", params: [sharesKey]))
            idToMeta[reqId] = (pair, .totalShares)
            reqId += 1
        }

        let responses = try await sendBatchRPCChunked(requests: requests)

        var totalAlphaMap: [PositionKey: BigUInt] = [:]
        var totalSharesMap: [PositionKey: BigUInt] = [:]

        for (id, meta) in idToMeta {
            switch meta.kind {
            case .totalAlpha:
                totalAlphaMap[meta.posKey] = decodeU64LE(hex: responses[id] ?? nil).map { BigUInt($0) } ?? 0
            case .totalShares:
                totalSharesMap[meta.posKey] = decodeU128LE(hex: responses[id] ?? nil)
            }
        }

        return positions.compactMap { pos -> SubtensorRawPosition? in
            let key = PositionKey(hotkey: pos.hotkey, netuid: pos.netuid)
            let totalAlpha = totalAlphaMap[key] ?? 0
            let totalShares = totalSharesMap[key] ?? 0

            let actualAmount: BigUInt
            if totalShares > 0 {
                actualAmount = (pos.shares * totalAlpha) / totalShares
            } else {
                actualAmount = 0
            }

            guard actualAmount > 0 else { return nil }

            return SubtensorRawPosition(
                hotkey: pos.hotkey,
                netuid: pos.netuid,
                amount: actualAmount
            )
        }
    }

    // MARK: - Storage key builders

    private static func stakingHotkeysKey(coldkey: AccountId) -> String {
        let moduleHash = twox128(b("SubtensorModule"))
        let itemHash = twox128(b("StakingHotkeys"))
        let keyHash = blake2_128(coldkey) + coldkey
        return hex(moduleHash + itemHash + keyHash)
    }

    private static func alphaKey(hotkey: AccountId, coldkey: AccountId, netuid: UInt16) -> String {
        let moduleHash = twox128(b("SubtensorModule"))
        let itemHash = twox128(b("Alpha"))
        let k1 = blake2_128(hotkey) + hotkey
        let k2 = blake2_128(coldkey) + coldkey
        let k3 = netuidLE(netuid)
        return hex(moduleHash + itemHash + k1 + k2 + k3)
    }

    private static func totalHotkeyAlphaKey(hotkey: AccountId, netuid: UInt16) -> String {
        let moduleHash = twox128(b("SubtensorModule"))
        let itemHash = twox128(b("TotalHotkeyAlpha"))
        let k1 = blake2_128(hotkey) + hotkey
        let k2 = netuidLE(netuid)
        return hex(moduleHash + itemHash + k1 + k2)
    }

    private static func totalHotkeySharesKey(hotkey: AccountId, netuid: UInt16) -> String {
        let moduleHash = twox128(b("SubtensorModule"))
        let itemHash = twox128(b("TotalHotkeyShares"))
        let k1 = blake2_128(hotkey) + hotkey
        let k2 = netuidLE(netuid)
        return hex(moduleHash + itemHash + k1 + k2)
    }

    // MARK: - Hash helpers

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

    /// Decodes a SCALE-encoded Vec<AccountId> (32-byte entries).
    static func decodeVecAccountId(hex: String) -> [AccountId] {
        let bytes = hexToBytes(hex)
        guard !bytes.isEmpty else { return [] }

        guard let (count, offset) = scaleCompact(bytes: bytes) else { return [] }
        let accountIdSize = 32
        guard offset + Int(count) * accountIdSize <= bytes.count else { return [] }

        var result: [AccountId] = []
        var pos = offset
        for _ in 0 ..< Int(count) {
            result.append(Data(bytes[pos ..< pos + accountIdSize]))
            pos += accountIdSize
        }
        return result
    }

    /// Decodes a SCALE-encoded u64 (8 bytes LE).
    private static func decodeU64LE(hex: String?) -> UInt64? {
        guard let hex = hex else { return nil }
        let bytes = hexToBytes(hex)
        guard bytes.count >= 8 else { return nil }
        return bytes.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: UInt64.self)
        }
    }

    /// Decodes a SCALE-encoded U128 (16 bytes LE) into BigUInt.
    private static func decodeU128LE(hex: String?) -> BigUInt {
        guard let hex = hex else { return 0 }
        let bytes = hexToBytes(hex)
        guard bytes.count >= 16 else { return 0 }
        // LE → BigUInt: reverse to get big-endian Data
        return BigUInt(Data(bytes.prefix(16).reversed()))
    }

    private static func hexToBytes(_ hex: String) -> [UInt8] {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var bytes: [UInt8] = []
        var idx = clean.startIndex
        while clean.index(idx, offsetBy: 2, limitedBy: clean.endIndex) != nil {
            let end = clean.index(idx, offsetBy: 2)
            bytes.append(UInt8(clean[idx ..< end], radix: 16) ?? 0)
            idx = end
        }
        return bytes
    }

    /// SCALE compact integer decode (supports 1, 2, 4 byte modes).
    private static func scaleCompact(bytes: [UInt8]) -> (value: UInt64, nextOffset: Int)? {
        guard !bytes.isEmpty else { return nil }
        let mode = bytes[0] & 0x03
        switch mode {
        case 0x00:
            return (UInt64(bytes[0] >> 2), 1)
        case 0x01:
            guard bytes.count >= 2 else { return nil }
            let val = (UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)) >> 2
            return (UInt64(val), 2)
        case 0x02:
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) |
                (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return (UInt64(raw >> 2), 4)
        default:
            return nil
        }
    }

    // MARK: - RPC transport

    private static func rpcRequest(id: Int, method: String, params: [Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
    }

    /// Splits large request sets into ≤500-item batches, merges results.
    private static func sendBatchRPCChunked(requests: [[String: Any]]) async throws -> [Int: String?] {
        let chunkSize = 500
        var combined: [Int: String?] = [:]

        var offset = 0
        while offset < requests.count {
            let chunk = Array(requests[offset ..< min(offset + chunkSize, requests.count)])
            let partial = try await sendBatchRPC(requests: chunk)
            for (key, val) in partial { combined[key] = val }
            offset += chunkSize
        }
        return combined
    }

    private static func sendBatchRPC(requests: [[String: Any]]) async throws -> [Int: String?] {
        let jsonData = try JSONSerialization.data(withJSONObject: requests)
        var req = URLRequest(url: rpcURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FetchError.invalidResponse
        }
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw FetchError.invalidResponse
        }

        var results: [Int: String?] = [:]
        for item in array {
            guard let id = item["id"] as? Int else { continue }
            results[id] = item["result"] as? String
        }
        return results
    }
}

// MARK: - Model

/// A resolved stake position with the actual computed alpha/TAO amount.
struct SubtensorRawPosition {
    /// Validator hotkey.
    let hotkey: AccountId
    /// Subnet identifier (0 = root).
    let netuid: UInt16
    /// Actual alpha amount in the subnet's smallest unit (RAO for root, alpha-unit for subnets).
    let amount: BigUInt
}
