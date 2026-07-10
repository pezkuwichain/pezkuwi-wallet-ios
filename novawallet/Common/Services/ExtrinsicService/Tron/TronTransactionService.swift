import Foundation
import BigInt
import Operation_iOS

enum TronTransactionServiceError: Error {
    // Defensive cross-check failure: the SHA-256 digest this app computed locally over the
    // `raw_data_hex` bytes TronGrid returned didn't match the `txID` TronGrid reported for the
    // same response. Live-verified against real Shasta testnet data that these are always equal
    // in normal operation (see `SigningWrapperProtocol.signTron`'s doc comment) - if this ever
    // fires, something about the transaction envelope was tampered with or misdecoded in transit,
    // and signing must not proceed.
    case txIdMismatch
    case invalidRawDataHex
    case invalidSignatureLength(Int)
}

typealias TronSubmitTransactionResult = Result<String, Error>
typealias TronSubmitTransactionClosure = (TronSubmitTransactionResult) -> Void
typealias TronEstimateFeeResult = Result<TronFeeModel, Error>
typealias TronEstimateFeeClosure = (TronEstimateFeeResult) -> Void

protocol TronTransactionServiceProtocol {
    func estimateFee(
        for type: TronTransferType,
        amount: BigUInt,
        recipient: AccountAddress,
        runningIn queue: DispatchQueue,
        completion: @escaping TronEstimateFeeClosure
    )

    func submit(
        for type: TronTransferType,
        amount: BigUInt,
        recipient: AccountAddress,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion: @escaping TronSubmitTransactionClosure
    )
}

/// Mirrors `EvmTransactionService`'s role (fee estimation + sign-and-submit orchestration for a
/// single account), but over TronGrid's REST endpoints instead of local RLP building + JSON-RPC.
///
/// Unlike `EvmTransactionService`, this deliberately does NOT try to express "build unsigned tx,
/// then sign it, then broadcast it" as a single `CompoundOperationWrapper` dependency graph: the
/// signature can only be computed once the *real* `raw_data_hex` bytes are known (there is no
/// local, pre-network way to predict them, since TronGrid itself assigns `ref_block_bytes`/
/// `ref_block_hash`/`expiration`/`timestamp`), so this is the same "dynamically build an operation
/// from another operation's not-yet-known result" shape `TronBalanceUpdatePersistentHandler`'s own
/// doc comment calls out as needing sequential completion-callback staging instead of one
/// `CompoundOperationWrapper` graph. Each stage below is a small, independently-queued step whose
/// completion callback kicks off the next stage - no nested `waitUntilFinished` calls, no operation
/// ever blocks the shared `operationQueue` waiting on another operation queued on that same queue.
final class TronTransactionService {
    let ownerAddress: AccountAddress
    let operationFactory: TronGridOperationFactoryProtocol
    let commandFactory: TronTransferCommandFactory
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    // A signed Tron `Transaction` protobuf message's `signature` field (`repeated bytes`, field
    // number 9) adds exactly 2 bytes of wire-format overhead (a 1-byte field tag + a 1-byte
    // varint length, since a single 65-byte entry's length fits in one varint byte) on top of the
    // 65 raw signature bytes themselves, for a fixed total of 67 bytes - this is a protobuf
    // wire-format fact, not a magic/guessed constant. Added to `raw_data_hex`'s own (exact, node
    // -reported) byte length to get the true final signed-transaction size used for bandwidth fee
    // estimation, rather than the ~268-byte rule-of-thumb some Tron docs quote for a generic
    // simple transfer.
    private static let signatureFieldOverheadBytes = 67

    // Safety margin applied on top of the raw TVM `energy_used` dry-run estimate (from
    // `triggerconstantcontract`), both for the *displayed* TRC20 fee and for the `fee_limit`
    // passed to the real `triggersmartcontract` build (which hard-caps how much TRX the network
    // may burn executing this call on-chain). A dry-run's energy estimate is a close but not
    // contractually exact predictor of real execution cost (e.g. storage-slot warm/cold cost can
    // shift by the time the real call executes). Underestimating `fee_limit` risks a call that
    // reverts after already burning the resources consumed up to the point of failure (a real,
    // user-visible loss); overestimating it only ever changes the cap, never what's actually
    // charged (Tron only burns energy actually consumed, never the limit itself), so erring high
    // is the safe direction. 30% is a reasonable-engineering-judgment margin, not independently
    // benchmarked against Tron mainnet's historical energy-estimate-vs-actual variance - flagged
    // for human review before mainnet.
    private let energyFeeLimitMarginMultiplier: BigUInt = 130
    private let energyFeeLimitMarginDivisor: BigUInt = 100

    init(
        ownerAddress: AccountAddress,
        operationFactory: TronGridOperationFactoryProtocol,
        commandFactory: TronTransferCommandFactory,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.ownerAddress = ownerAddress
        self.operationFactory = operationFactory
        self.commandFactory = commandFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private: shared fee math

private extension TronTransactionService {
    struct ResourceContext {
        let resource: TronGridAccountResourceResponse
        let params: TronGridChainParametersResponse
    }

    func createResourceContextWrapper() -> CompoundOperationWrapper<ResourceContext> {
        let resourceOperation = operationFactory.createAccountResourceOperation(for: ownerAddress)
        let paramsOperation = operationFactory.createChainParametersOperation()

        let mapOperation = ClosureOperation<ResourceContext> {
            let resource = try resourceOperation.extractNoCancellableResultData()
            let params = try paramsOperation.extractNoCancellableResultData()
            return ResourceContext(resource: resource, params: params)
        }

        mapOperation.addDependency(resourceOperation)
        mapOperation.addDependency(paramsOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [resourceOperation, paramsOperation]
        )
    }

    func bandwidthFee(
        forTransactionByteCount txBytes: Int,
        context: ResourceContext
    ) throws -> BigUInt {
        guard let feePerByte = context.params.transactionFeePerByte else {
            throw TronGridOperationFactoryError.missingChainParameter("getTransactionFee")
        }

        let shortfall = max(0, txBytes - context.resource.availableBandwidthInBytes)
        return BigUInt(shortfall) * BigUInt(feePerByte)
    }

    func energyFee(forEnergyUsed energyUsed: Int, context: ResourceContext) throws -> BigUInt {
        guard let feePerUnit = context.params.energyFeePerUnit else {
            throw TronGridOperationFactoryError.missingChainParameter("getEnergyFee")
        }

        let shortfall = max(0, energyUsed - context.resource.availableEnergy)
        return BigUInt(shortfall) * BigUInt(feePerUnit)
    }

    func signedByteCount(forRawDataHex rawDataHex: String) -> Int {
        rawDataHex.count / 2 + Self.signatureFieldOverheadBytes
    }

    /// Combines a just-built (unsigned, real) transaction with account resources/chain params
    /// into a `TronFeeModel`. Shared by the native and TRC20 estimate paths.
    func computeNativeStyleFee(
        transaction: TronGridUnsignedTransaction,
        context: ResourceContext
    ) throws -> TronFeeModel {
        let txBytes = signedByteCount(forRawDataHex: transaction.rawDataHex)
        let fee = try bandwidthFee(forTransactionByteCount: txBytes, context: context)
        return TronFeeModel(bandwidthFeeInSun: fee, energyFeeInSun: 0)
    }

    func computeTrc20Fee(
        transaction: TronGridUnsignedTransaction,
        energyUsed: Int,
        context: ResourceContext
    ) throws -> (fee: TronFeeModel, feeLimitInSun: BigUInt) {
        let txBytes = signedByteCount(forRawDataHex: transaction.rawDataHex)
        let bandwidthFee = try bandwidthFee(forTransactionByteCount: txBytes, context: context)
        let rawEnergyFee = try energyFee(forEnergyUsed: energyUsed, context: context)
        let marginedEnergyFee = (rawEnergyFee * energyFeeLimitMarginMultiplier) / energyFeeLimitMarginDivisor

        let fee = TronFeeModel(bandwidthFeeInSun: bandwidthFee, energyFeeInSun: marginedEnergyFee)

        return (fee: fee, feeLimitInSun: marginedEnergyFee)
    }

    // MARK: Signing and broadcast (final stage, shared by native and TRC20)

    func tronSignatureHex(rawDataBytes: Data, signer: SigningWrapperProtocol) throws -> String {
        let rawSignature = try signer.sign(rawDataBytes, context: .rawBytes).rawData()

        guard rawSignature.count == 65 else {
            throw TronTransactionServiceError.invalidSignatureLength(rawSignature.count)
        }

        var tronSignature = rawSignature

        // `SECSigner` (invoked via `SigningWrapperProtocol.signTron`) returns the *raw* secp256k1
        // recovery id (0 or 1) as the last byte. Tron's wire format expects `recid + 27` instead
        // (the same convention as classic, pre-EIP-155 Ethereum message signatures) - confirmed
        // both by independently recovering the public key from a real Shasta testnet transaction's
        // actual on-chain signature (the real byte was `28 = 27 + 1`) and by reading TronGrid's own
        // reference JS signing code (`ECKeySign` in `tronweb/src/utils/crypto.ts`, which computes
        // `signature.recovery! + 27`). See `SigningWrapperProtocol.signTron`'s doc comment for the
        // full verification writeup.
        tronSignature[tronSignature.count - 1] = rawSignature[rawSignature.count - 1] + 27

        return tronSignature.toHex()
    }

    func signAndBroadcast(
        transaction: TronGridUnsignedTransaction,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion: @escaping TronSubmitTransactionClosure
    ) {
        let signatureHex: String

        do {
            guard let rawDataBytes = try? Data(hexString: transaction.rawDataHex) else {
                throw TronTransactionServiceError.invalidRawDataHex
            }

            let digest = rawDataBytes.sha256()

            guard digest.toHex() == transaction.txID else {
                throw TronTransactionServiceError.txIdMismatch
            }

            signatureHex = try tronSignatureHex(rawDataBytes: rawDataBytes, signer: signer)
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completion(.failure(error))
            }
            return
        }

        let broadcastOperation = operationFactory.createBroadcastOperation(
            transaction: transaction,
            signatureHex: signatureHex
        )

        broadcastOperation.completionBlock = {
            queue.async {
                do {
                    let response = try broadcastOperation.extractNoCancellableResultData()

                    guard response.isSuccess else {
                        throw TronGridOperationFactoryError.broadcastFailed(
                            code: response.code,
                            message: response.decodedMessage
                        )
                    }

                    completion(.success(transaction.txID))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        operationQueue.addOperations([broadcastOperation], waitUntilFinished: false)
    }
}

// MARK: - TronTransactionServiceProtocol

extension TronTransactionService: TronTransactionServiceProtocol {
    func estimateFee(
        for type: TronTransferType,
        amount: BigUInt,
        recipient: AccountAddress,
        runningIn queue: DispatchQueue,
        completion: @escaping TronEstimateFeeClosure
    ) {
        switch type {
        case .native:
            let buildOperation = commandFactory.buildTransferOperation(
                ownerAddress: ownerAddress,
                recipient: recipient,
                amount: amount,
                type: .native,
                feeLimitInSun: 0
            )
            let contextWrapper = createResourceContextWrapper()

            let mapOperation = ClosureOperation<TronFeeModel> { [self] in
                let transaction = try buildOperation.extractNoCancellableResultData()
                let context = try contextWrapper.targetOperation.extractNoCancellableResultData()
                return try computeNativeStyleFee(transaction: transaction, context: context)
            }

            mapOperation.addDependency(buildOperation)
            mapOperation.addDependency(contextWrapper.targetOperation)

            mapOperation.completionBlock = {
                queue.async {
                    do {
                        completion(.success(try mapOperation.extractNoCancellableResultData()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }

            let operations = [buildOperation] + contextWrapper.allOperations + [mapOperation]
            operationQueue.addOperations(operations, waitUntilFinished: false)

        case let .trc20(contractAddress):
            let energyOperation = operationFactory.createTrc20TransferEnergyEstimateOperation(
                ownerAddress: ownerAddress,
                contractAddress: contractAddress,
                toAddress: recipient,
                amountInPlank: amount
            )
            let contextWrapper = createResourceContextWrapper()
            // Placeholder `fee_limit` purely for byte-size measurement - see the doc comment on
            // `submit`'s TRC20 branch for why the real transaction is always rebuilt (and
            // re-measured) with the real fee_limit right before signing.
            let sizingBuildOperation = commandFactory.buildTransferOperation(
                ownerAddress: ownerAddress,
                recipient: recipient,
                amount: amount,
                type: type,
                feeLimitInSun: 100_000_000
            )

            let mapOperation = ClosureOperation<TronFeeModel> { [self] in
                let energyUsed = try energyOperation.extractNoCancellableResultData()
                let context = try contextWrapper.targetOperation.extractNoCancellableResultData()
                let transaction = try sizingBuildOperation.extractNoCancellableResultData()

                return try computeTrc20Fee(transaction: transaction, energyUsed: energyUsed, context: context).fee
            }

            mapOperation.addDependency(energyOperation)
            mapOperation.addDependency(contextWrapper.targetOperation)
            mapOperation.addDependency(sizingBuildOperation)

            mapOperation.completionBlock = {
                queue.async {
                    do {
                        completion(.success(try mapOperation.extractNoCancellableResultData()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }

            let operations = [energyOperation, sizingBuildOperation] + contextWrapper.allOperations + [mapOperation]
            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }

    func submit(
        for type: TronTransferType,
        amount: BigUInt,
        recipient: AccountAddress,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion: @escaping TronSubmitTransactionClosure
    ) {
        switch type {
        case .native:
            let buildOperation = commandFactory.buildTransferOperation(
                ownerAddress: ownerAddress,
                recipient: recipient,
                amount: amount,
                type: .native,
                feeLimitInSun: 0
            )

            buildOperation.completionBlock = { [self] in
                do {
                    let transaction = try buildOperation.extractNoCancellableResultData()
                    signAndBroadcast(transaction: transaction, signer: signer, runningIn: queue, completion: completion)
                } catch {
                    queue.async {
                        completion(.failure(error))
                    }
                }
            }

            operationQueue.addOperations([buildOperation], waitUntilFinished: false)

        case let .trc20(contractAddress):
            // Stage 1: figure out how much `fee_limit` this call needs (fresh, not reused from
            // whatever `estimateFee` last computed for the UI preview - mirrors how
            // `EvmTransactionService.submit` always fetches a fresh nonce rather than reusing an
            // estimate-time value). Stage 2 (in the completion callback below) then builds the
            // REAL to-be-signed transaction with that real `fee_limit`, and stage 3 signs+broadcasts
            // it - each stage only starts once the previous one's real network response is known,
            // per this type's top-level doc comment on why this isn't one dependency graph.
            let energyOperation = operationFactory.createTrc20TransferEnergyEstimateOperation(
                ownerAddress: ownerAddress,
                contractAddress: contractAddress,
                toAddress: recipient,
                amountInPlank: amount
            )
            let contextWrapper = createResourceContextWrapper()
            let sizingBuildOperation = commandFactory.buildTransferOperation(
                ownerAddress: ownerAddress,
                recipient: recipient,
                amount: amount,
                type: type,
                feeLimitInSun: 100_000_000
            )

            let feeLimitOperation = ClosureOperation<BigUInt> { [self] in
                let energyUsed = try energyOperation.extractNoCancellableResultData()
                let context = try contextWrapper.targetOperation.extractNoCancellableResultData()
                let transaction = try sizingBuildOperation.extractNoCancellableResultData()

                return try computeTrc20Fee(
                    transaction: transaction,
                    energyUsed: energyUsed,
                    context: context
                ).feeLimitInSun
            }

            feeLimitOperation.addDependency(energyOperation)
            feeLimitOperation.addDependency(contextWrapper.targetOperation)
            feeLimitOperation.addDependency(sizingBuildOperation)

            feeLimitOperation.completionBlock = { [self] in
                do {
                    let feeLimitInSun = try feeLimitOperation.extractNoCancellableResultData()

                    let realBuildOperation = commandFactory.buildTransferOperation(
                        ownerAddress: ownerAddress,
                        recipient: recipient,
                        amount: amount,
                        type: type,
                        feeLimitInSun: feeLimitInSun
                    )

                    realBuildOperation.completionBlock = { [self] in
                        do {
                            let transaction = try realBuildOperation.extractNoCancellableResultData()
                            signAndBroadcast(
                                transaction: transaction,
                                signer: signer,
                                runningIn: queue,
                                completion: completion
                            )
                        } catch {
                            queue.async {
                                completion(.failure(error))
                            }
                        }
                    }

                    operationQueue.addOperations([realBuildOperation], waitUntilFinished: false)
                } catch {
                    queue.async {
                        completion(.failure(error))
                    }
                }
            }

            let operations = [energyOperation, sizingBuildOperation] + contextWrapper.allOperations +
                [feeLimitOperation]
            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }
}
