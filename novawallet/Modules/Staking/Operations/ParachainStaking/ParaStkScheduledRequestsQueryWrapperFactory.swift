import Foundation
import SubstrateSdk
import Operation_iOS

// For more convenient usage cause of long type name
private typealias Interface = ParaStkScheduledRequestsQueryWrapperFactoryProtocol

typealias DelegationRequestsQueryResult = [StorageResponse<[ParachainStaking.ScheduledRequest]>]

protocol ParaStkScheduledRequestsQueryWrapperFactoryProtocol {
    func createQueryWrapper<K1, K2>(
        using connection: JSONRPCEngine,
        with collators: @escaping () throws -> [K1],
        delegator: @escaping () throws -> K2,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<DelegationRequestsQueryResult> where K1: Encodable, K2: Encodable
}

extension ParaStkScheduledRequestsQueryWrapperFactoryProtocol {
    func createQueryWrapper<K1, K2>(
        using connection: JSONRPCEngine,
        with collators: @escaping () throws -> [K1],
        delegator: @escaping () throws -> K2,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        at blockHash: Data? = nil
    ) -> CompoundOperationWrapper<DelegationRequestsQueryResult> where K1: Encodable, K2: Encodable {
        createQueryWrapper(
            using: connection,
            with: collators,
            delegator: delegator,
            codingFactory: codingFactory,
            at: blockHash
        )
    }
}

final class ParaStkScheduledRequestsQueryWrapperFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
    }
}

extension ParaStkScheduledRequestsQueryWrapperFactory: Interface {
    func createQueryWrapper<K1, K2>(
        using connection: JSONRPCEngine,
        with collators: @escaping () throws -> [K1],
        delegator: @escaping () throws -> K2,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<DelegationRequestsQueryResult> where K1: Encodable, K2: Encodable {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let codingFactory = try codingFactory()
            let metadata = codingFactory.metadata

            let storageMetadata = metadata.getStorageMetadata(
                for: ParachainStaking.delegationRequestsPath
            )

            guard let storageMetadata else { throw ParaStkRequestsQueryError.storageMetadataNotFound }

            return switch storageMetadata.type {
            case .map:
                storageRequestFactory.queryItems(
                    engine: connection,
                    keyParams: collators,
                    factory: { codingFactory },
                    storagePath: ParachainStaking.delegationRequestsPath,
                    at: blockHash
                )
            case .doubleMap:
                storageRequestFactory.queryItems(
                    engine: connection,
                    keyParams1: collators,
                    keyParams2: { try Array(repeating: try delegator(), count: collators().count) },
                    factory: { codingFactory },
                    storagePath: ParachainStaking.delegationRequestsPath,
                    at: blockHash
                )
            default:
                throw ParaStkRequestsQueryError.unexpectedStorageType
            }
        }
    }
}

// MARK: - Errors

enum ParaStkRequestsQueryError: Error {
    case storageMetadataNotFound
    case unexpectedStorageType
}
