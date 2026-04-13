import Foundation
import BigInt
import Operation_iOS
import xxHash_Swift

/// Queries Bittensor chain storage to compute the user's total root-network
/// (netuid=0) TAO stake and persists it to the multistaking dashboard repository.
///
/// Root alpha positions are 1:1 TAO-denominated, so their sum is the "TAO staked"
/// figure shown on the main staking dashboard row.
///
/// Unlike Mythos/Parachain update services, this service uses one-shot HTTP
/// JSON-RPC calls (same transport as SubtensorPositionFetcher) instead of
/// WebSocket storage subscriptions, because Bittensor positions span many
/// dynamic storage keys that can't be tracked with a single subscription.
final class SubtensorMultistakingUpdateService: ObservableSyncService {
    let walletId: MetaAccountModel.Id
    let accountId: AccountId
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>
    let operationQueue: OperationQueue

    private let rpcURL: URL
    private var fetchTask: Task<Void, Never>?

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.walletId = walletId
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.operationQueue = operationQueue

        let nodeURL = chainAsset.chain.nodes
            .compactMap { URL(string: $0.url) }
            .filter { $0.scheme == "https" || $0.scheme == "http" }
            .first ?? URL(string: "https://entrypoint-finney.opentensor.ai")!
        rpcURL = nodeURL

        super.init(logger: logger)
    }

    // MARK: - ObservableSyncService

    override func performSyncUp() {
        guard fetchTask == nil else { return }
        markSyncingImmediate()

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let total = try await self.fetchTotalRootStake()
                try await self.persist(totalStake: total)
                self.fetchTask = nil
                self.completeImmediate(nil)
            } catch {
                guard !Task.isCancelled else { return }
                self.fetchTask = nil
                self.completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    // MARK: - Fetch

    private func fetchTotalRootStake() async throws -> BigUInt {
        // Step 1: hotkeys for this coldkey
        let hkHex = Self.stakingHotkeysKey(coldkey: accountId)
        let hkResult = try await Self.storageRequest(url: rpcURL, key: hkHex)
        guard let hkData = hkResult else { return .zero }
        let hotkeys = Self.decodeVecAccountId(hex: hkData)
        guard !hotkeys.isEmpty else { return .zero }

        // Step 2: Alpha shares (root only), TotalHotkeyAlpha, TotalHotkeyShares
        var requests: [[String: Any]] = []
        var idToMeta: [Int: (hotkey: AccountId, kind: FetchKind)] = [:]
        var reqId = 0

        for hotkey in hotkeys {
            requests.append(Self.rpcRequest(id: reqId, key: Self.alphaKey(hotkey: hotkey, coldkey: accountId, netuid: 0)))
            idToMeta[reqId] = (hotkey, .alphaShares)
            reqId += 1

            requests.append(Self.rpcRequest(id: reqId, key: Self.totalHotkeyAlphaKey(hotkey: hotkey, netuid: 0)))
            idToMeta[reqId] = (hotkey, .totalAlpha)
            reqId += 1

            requests.append(Self.rpcRequest(id: reqId, key: Self.totalHotkeySharesKey(hotkey: hotkey, netuid: 0)))
            idToMeta[reqId] = (hotkey, .totalShares)
            reqId += 1
        }

        let responses = try await Self.sendBatch(requests: requests, url: rpcURL)

        // Step 3: compute actual amounts per hotkey
        var alphaSharesMap: [Data: BigUInt] = [:]
        var totalAlphaMap: [Data: BigUInt] = [:]
        var totalSharesMap: [Data: BigUInt] = [:]

        for (id, meta) in idToMeta {
            let hex = responses[id] ?? nil
            switch meta.kind {
            case .alphaShares:
                alphaSharesMap[meta.hotkey] = Self.decodeU128LE(hex: hex)
            case .totalAlpha:
                totalAlphaMap[meta.hotkey] = Self.decodeU64LE(hex: hex).map { BigUInt($0) } ?? .zero
            case .totalShares:
                totalSharesMap[meta.hotkey] = Self.decodeU128LE(hex: hex)
            }
        }

        var total = BigUInt.zero
        for hotkey in hotkeys {
            let shares = alphaSharesMap[hotkey] ?? .zero
            guard shares > 0 else { continue }
            let tha = totalAlphaMap[hotkey] ?? .zero
            let ths = totalSharesMap[hotkey] ?? .zero
            guard ths > 0 else { continue }
            total += (shares * tha) / ths
        }
        return total
    }

    private enum FetchKind {
        case alphaShares, totalAlpha, totalShares
    }

    // MARK: - Persist

    private func persist(totalStake: BigUInt) async throws {
        let option = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )
        let item = Multistaking.DashboardItemSubtensorPart(
            stakingOption: option,
            state: .init(totalStake: totalStake)
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let saveOp = dashboardRepository.saveOperation({ [item] }, { [] })
            saveOp.completionBlock = {
                switch saveOp.result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                case .none:
                    continuation.resume()
                }
            }
            operationQueue.addOperation(saveOp)
        }
    }

    // MARK: - Storage key builders (mirrors SubtensorPositionFetcher)

    private static func stakingHotkeysKey(coldkey: AccountId) -> String {
        let prefix = twox128(b("SubtensorModule")) + twox128(b("StakingHotkeys"))
        let keySuffix = blake2_128(coldkey) + coldkey
        return hex(prefix + keySuffix)
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

    private static func storageRequest(url: URL, key: String) async throws -> String? {
        let results = try await sendBatch(requests: [rpcRequest(id: 0, key: key)], url: url)
        return results[0] ?? nil
    }

    private static func sendBatch(requests: [[String: Any]], url: URL) async throws -> [Int: String?] {
        let body = try JSONSerialization.data(withJSONObject: requests)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SubtensorFetchError.invalidResponse
        }

        // Single response (non-array) for single-item batch
        if let single = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = single["id"] as? Int {
            return [id: single["result"] as? String]
        }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SubtensorFetchError.invalidResponse
        }

        var results: [Int: String?] = [:]
        for item in array {
            guard let id = item["id"] as? Int else { continue }
            results[id] = item["result"] as? String
        }
        return results
    }
}

private enum SubtensorFetchError: Error {
    case invalidResponse
}
