import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

/// JSON response of `GET https://telegram.pezkiwi.app/kurds` — the "Hejmara Kurd Le Cihane"
/// (world Kurdish population) counter also used by the Android sibling app.
struct PezkuwiWelatiCountResponse: Decodable {
    let count: Int
}

protocol PezkuwiDashboardRepositoryProtocol {
    /// Fetches the dashboard data for `accountId` on the Pezkuwi People chain.
    ///
    /// Mirrors the Android sibling app's `PezkuwiDashboardRepository.getDashboard(accountId)` —
    /// every sub-query (roles, trust score, tracking flag, KYC/citizenship status, world Kurdish
    /// population counter) is best-effort: a failure in one sub-query degrades to its own default
    /// value instead of failing the whole dashboard.
    func fetchDashboardWrapper(for accountId: AccountId) -> CompoundOperationWrapper<PezkuwiDashboardData>
}

final class PezkuwiDashboardRepository: PezkuwiDashboardRepositoryProtocol {
    static let defaultWelatiCountURL = URL(string: "https://telegram.pezkiwi.app/kurds")!

    private let chainRegistry: ChainRegistryProtocol
    private let requestFactory: StorageRequestFactoryProtocol
    private let welatiCountURL: URL

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        welatiCountURL: URL = PezkuwiDashboardRepository.defaultWelatiCountURL
    ) {
        self.chainRegistry = chainRegistry
        self.welatiCountURL = welatiCountURL

        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func fetchDashboardWrapper(for accountId: AccountId) -> CompoundOperationWrapper<PezkuwiDashboardData> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: KnowChainId.pezkuwiPeople)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: KnowChainId.pezkuwiPeople)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let rolesWrapper = queryStorageItemWrapper(
                moduleName: "Tiki",
                itemName: "UserTikis",
                accountId: accountId,
                connection: connection,
                codingFactoryOperation: codingFactoryOperation
            )

            let trustScoreWrapper = queryStorageItemWrapper(
                moduleName: "Trust",
                itemName: "TrustScores",
                accountId: accountId,
                connection: connection,
                codingFactoryOperation: codingFactoryOperation
            )

            let trackingWrapper = queryStorageItemWrapper(
                moduleName: "StakingScore",
                itemName: "StakingStartBlock",
                accountId: accountId,
                connection: connection,
                codingFactoryOperation: codingFactoryOperation
            )

            let kycWrapper = queryStorageItemWrapper(
                moduleName: "IdentityKyc",
                itemName: "KycStatuses",
                accountId: accountId,
                connection: connection,
                codingFactoryOperation: codingFactoryOperation
            )

            let welatiOperation = createWelatiCountOperation()

            let mergeOperation = ClosureOperation<PezkuwiDashboardData> {
                let rolesValue = (try? rolesWrapper.targetOperation.extractNoCancellableResultData())?.first?.value
                let roles = Self.extractRoles(from: rolesValue)

                let trustScoreValue = (
                    try? trustScoreWrapper.targetOperation.extractNoCancellableResultData()
                )?.first?.value
                let trustScore = trustScoreValue?.toBigUInt() ?? 0

                let trackingValue = (
                    try? trackingWrapper.targetOperation.extractNoCancellableResultData()
                )?.first?.value
                let isTrackingScore = trackingValue != nil

                let kycValue = (try? kycWrapper.targetOperation.extractNoCancellableResultData())?.first?.value
                let citizenshipStatus = Self.extractCitizenshipStatus(from: kycValue)

                let welatiCount = (try? welatiOperation.extractNoCancellableResultData().count) ?? 0

                return PezkuwiDashboardData(
                    roles: roles,
                    trustScore: trustScore,
                    welatiCount: welatiCount,
                    citizenshipStatus: citizenshipStatus,
                    isTrackingScore: isTrackingScore
                )
            }

            mergeOperation.addDependency(rolesWrapper.targetOperation)
            mergeOperation.addDependency(trustScoreWrapper.targetOperation)
            mergeOperation.addDependency(trackingWrapper.targetOperation)
            mergeOperation.addDependency(kycWrapper.targetOperation)
            mergeOperation.addDependency(welatiOperation)

            let dependencies = [codingFactoryOperation]
                + rolesWrapper.allOperations
                + trustScoreWrapper.allOperations
                + trackingWrapper.allOperations
                + kycWrapper.allOperations
                + [welatiOperation]

            return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}

// MARK: - Private

private extension PezkuwiDashboardRepository {
    /// Ad hoc "look up module by name, storage item by name, decode dynamically" query for a
    /// single account key — mirrors `WalletRemoteQueryWrapperFactory.queryNativeBalance` but with
    /// a fully dynamic `JSON` result type instead of a typed Decodable, since `Tiki`, `Trust`,
    /// `StakingScore` and `IdentityKyc` are custom Pezkuwi pallets with no generated Swift bindings.
    func queryStorageItemWrapper(
        moduleName: String,
        itemName: String,
        accountId: AccountId,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<JSON>]> {
        let storagePath = StorageCodingPath(moduleName: moduleName, itemName: itemName)

        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: accountId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: storagePath
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        return wrapper
    }

    func createWelatiCountOperation() -> BaseOperation<PezkuwiWelatiCountResponse> {
        let url = welatiCountURL

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<PezkuwiWelatiCountResponse> { data in
            try JSONDecoder().decode(PezkuwiWelatiCountResponse.self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    /// A Rust enum-with-data (dict-enum) decodes dynamically as `JSON.dictionaryValue(["Variant": payload])`;
    /// a fieldless enum may decode either the same way or as a bare `JSON.stringValue("Variant")`
    /// depending on metadata — both shapes are handled defensively.
    static func extractRoles(from json: JSON?) -> [String] {
        guard let json, case let .arrayValue(items) = json else { return [] }

        return items.compactMap { item -> String? in
            switch item {
            case let .dictionaryValue(dict):
                return dict.keys.first
            case let .stringValue(value):
                return value
            default:
                return nil
            }
        }
    }

    static func extractCitizenshipStatus(from json: JSON?) -> PezkuwiCitizenshipStatus {
        guard let json else { return .notStarted }

        let variantName: String?

        switch json {
        case let .dictionaryValue(dict):
            variantName = dict.keys.first
        case let .stringValue(value):
            variantName = value
        default:
            variantName = nil
        }

        return PezkuwiCitizenshipStatus(remoteVariantName: variantName)
    }
}
