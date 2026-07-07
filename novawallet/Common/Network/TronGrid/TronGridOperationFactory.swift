import Foundation
import Operation_iOS
import BigInt

enum TronGridOperationFactoryError: Error {
    case invalidAddress
    case invalidContractAddress
    case contractCallFailed(String?)
    // `POST /wallet/createtransaction` or `/wallet/triggersmartcontract` replied with an
    // application-level `{"Error": "..."}`/`{"result":{"result":false,"message":"..."}}` body
    // (HTTP 200, not a transport failure) - e.g. sender account never activated on-chain, or
    // (for a native transfer) sender == recipient. Verified live against Shasta testnet (2026).
    case buildTransactionFailed(String?)
    // `POST /wallet/broadcasttransaction` replied with a non-success body, e.g. `{"code":
    // "SIGERROR", ...}`. Verified live against Shasta testnet (2026) for the `SIGERROR` case.
    case broadcastFailed(code: String?, message: String?)
    case missingChainParameter(String)
    case amountTooLarge
}

protocol TronGridOperationFactoryProtocol {
    func createNativeBalanceOperation(for address: AccountAddress) -> BaseOperation<BigUInt>

    func createTrc20BalanceOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress
    ) -> BaseOperation<BigUInt>

    /// Builds (but does not sign or broadcast) a native TRX transfer via TronGrid's own
    /// `/wallet/createtransaction` endpoint - this app never constructs Tron's `Transaction`
    /// protobuf message itself (see the type-level doc comment below).
    func createNativeTransferBuildOperation(
        ownerAddress: AccountAddress,
        toAddress: AccountAddress,
        amountInPlank: BigUInt
    ) -> BaseOperation<TronGridUnsignedTransaction>

    /// Builds (but does not sign or broadcast) a TRC20 `transfer(address,uint256)` call via
    /// TronGrid's `/wallet/triggersmartcontract` endpoint. `feeLimitInSun` bounds the maximum TRX
    /// the network is allowed to burn for TVM energy while executing this call on-chain - the
    /// caller is expected to have already estimated a reasonable value (see
    /// `createTrc20TransferEnergyEstimateOperation` below) before calling this.
    func createTrc20TransferBuildOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress,
        toAddress: AccountAddress,
        amountInPlank: BigUInt,
        feeLimitInSun: BigUInt
    ) -> BaseOperation<TronGridUnsignedTransaction>

    /// Dry-runs a TRC20 `transfer(address,uint256)` call through the same
    /// `/wallet/triggerconstantcontract` endpoint Phase 1 already uses for the read-only
    /// `balanceOf` call, but with the real transfer parameters, to obtain a TVM energy estimate
    /// for fee-preview purposes without spending anything or requiring a signature.
    func createTrc20TransferEnergyEstimateOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress,
        toAddress: AccountAddress,
        amountInPlank: BigUInt
    ) -> BaseOperation<Int>

    /// Submits a signed transaction (as built by either of the two `...BuildOperation`s above,
    /// plus a signature produced independently - see `SigningWrapperProtocol.signTron`) to the
    /// network via `/wallet/broadcasttransaction`.
    func createBroadcastOperation(
        transaction: TronGridUnsignedTransaction,
        signatureHex: String
    ) -> BaseOperation<TronGridBroadcastResponse>

    /// Bandwidth/energy resource snapshot for `address`, used to determine how much of a planned
    /// transfer's cost would actually be burned as a fee vs. covered by free/staked allotment.
    func createAccountResourceOperation(for address: AccountAddress) -> BaseOperation<TronGridAccountResourceResponse>

    /// Network-wide fee parameters (sun-per-byte-of-bandwidth, sun-per-unit-of-energy).
    func createChainParametersOperation() -> BaseOperation<TronGridChainParametersResponse>
}

/// Standalone REST client for TronGrid (https://api.trongrid.io), mirroring the
/// `Common/Network/Etherscan/` request/response factory style. Tron is not JSON-RPC/EVM-compatible
/// at the transport layer, so this deliberately does not go through `ChainRegistry`'s
/// `ConnectionPool`/`JSONRPCEngine` machinery used for Substrate and EVM chains - see
/// `Common/Model/Tron/ChainModel+Tron.swift` for the rationale.
///
/// Phase 2 (send/transfer) additions below deliberately never construct Tron's
/// `Transaction`/`TransferContract`/`TriggerSmartContract` protobuf messages in this app - doing
/// so would be new, real crypto-adjacent risk. Instead, unsigned transactions are always built by
/// asking TronGrid's own node to do it (`/wallet/createtransaction`,
/// `/wallet/triggersmartcontract`), this app only computes the ECDSA signature over the
/// node-returned `raw_data` and re-submits the exact same envelope plus that signature to
/// `/wallet/broadcasttransaction`. See `SigningWrapperProtocol.signTron` for the signing step.
final class TronGridOperationFactory {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    // Tron's "hex form" address representation, as expected by `owner_address`/`contract_address`
    // fields in TronGrid's `triggerconstantcontract` request (with `visible: false`): the same
    // `0x41`-prefixed 21 bytes used for Base58Check display encoding, just hex-encoded (lowercase,
    // no "0x" prefix) instead. NOT the same as the ABI `parameter` encoding below (20 bytes, no
    // `0x41` prefix, zero-padded to 32 bytes) - verified as two genuinely different encodings
    // against the live API during implementation (see `TronGridTriggerConstantContractResponse`).
    private func tronHexAddress(from address: AccountAddress) throws -> String {
        guard let accountId = try? address.toAccountId(using: .tron) else {
            throw TronGridOperationFactoryError.invalidAddress
        }

        return (Data([TronConstants.addressVersionByte]) + accountId).toHex()
    }

    // Solidity ABI encoding of a single `address` parameter: the 20-byte account id, left-padded
    // with 12 zero bytes to a 32-byte word (`address` is treated as `uint160` for ABI purposes).
    private func abiEncodedAddressParameter(from address: AccountAddress) throws -> String {
        guard let accountId = try? address.toAccountId(using: .tron) else {
            throw TronGridOperationFactoryError.invalidAddress
        }

        let padding = Data(repeating: 0, count: 12)
        return (padding + accountId).toHex()
    }

    // Solidity ABI encoding of a single `uint256` parameter: big-endian minimal bytes,
    // left-padded with zero bytes to a full 32-byte word. Same `BigUInt.serialize()` (big-endian,
    // minimal-length) primitive already used elsewhere in this project for EVM chain id encoding
    // (see `ChainModel+Evm.swift`'s `evmChainId`), just zero-padded here to the fixed 32-byte ABI
    // word width instead of left as a variable-length hex string.
    private func abiEncodedUInt256Parameter(from value: BigUInt) throws -> String {
        let bytes = value.serialize()

        guard bytes.count <= 32 else {
            throw TronGridOperationFactoryError.amountTooLarge
        }

        let padding = Data(repeating: 0, count: 32 - bytes.count)
        return (padding + bytes).toHex()
    }

    // TronGrid's `amount`/`value` JSON fields for these endpoints are bare (non-string) integers
    // (confirmed live for `createtransaction`'s `amount` field on Shasta testnet, 2026) - encoded
    // here as `UInt64` rather than `BigUInt` (which isn't itself `Encodable` in this project's
    // BigInt package - see the identical rationale already documented on
    // `TronGridAccountResponse.balance`) since both TRX's total supply (~1.45e17 sun) and any
    // realistic single TRC20 transfer amount comfortably fit under `UInt64.max` (~1.8e19).
    private func requireUInt64(_ value: BigUInt) throws -> UInt64 {
        guard let result = UInt64(exactly: value) else {
            throw TronGridOperationFactoryError.amountTooLarge
        }

        return result
    }
}

// Plain `Encodable` structs for the new Phase 2 request bodies, following the same rationale as
// `TriggerConstantContractRequest` above (avoids depending on the exact case set of this
// project's generic `JSON` enum for request encoding - only used for *decoding* the opaque
// `raw_data` payload we round-trip, via `TronGridUnsignedTransaction`).
private struct CreateTransactionRequest: Encodable {
    let ownerAddress: String
    let toAddress: String
    let amount: UInt64
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case toAddress = "to_address"
        case amount
        case visible
    }
}

private struct TriggerSmartContractRequest: Encodable {
    let ownerAddress: String
    let contractAddress: String
    let functionSelector: String
    let parameter: String
    let feeLimit: UInt64?
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case contractAddress = "contract_address"
        case functionSelector = "function_selector"
        case parameter
        case feeLimit = "fee_limit"
        case visible
    }
}

private struct AccountResourceRequest: Encodable {
    let address: String
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case address
        case visible
    }
}

// Plain `Encodable` struct for the request body, rather than this project's generic `JSON` enum
// (from the external SubstrateSdk package) - avoids depending on that enum's exact case set
// (e.g. whether it has a boolean-value constructor case) since its source isn't inspectable in
// this environment; a dedicated `Codable` type is self-evidently correct instead.
private struct TriggerConstantContractRequest: Encodable {
    let ownerAddress: String
    let contractAddress: String
    let functionSelector: String
    let parameter: String
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case contractAddress = "contract_address"
        case functionSelector = "function_selector"
        case parameter
        case visible
    }
}

extension TronGridOperationFactory: TronGridOperationFactoryProtocol {
    func createNativeBalanceOperation(for address: AccountAddress) -> BaseOperation<BigUInt> {
        let url = baseUrl.appendingPathComponent("v1/accounts/\(address)")

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            request.setValue(UserAgent.nova, forHTTPHeaderField: "User-Agent")
            return request
        }

        let resultFactory = AnyNetworkResultFactory<BigUInt> { data in
            let response = try JSONDecoder().decode(TronGridAccountResponse.self, from: data)
            return response.trxBalance
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTrc20BalanceOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress
    ) -> BaseOperation<BigUInt> {
        let url = baseUrl.appendingPathComponent("wallet/triggerconstantcontract")

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let body = TriggerConstantContractRequest(
                ownerAddress: try tronHexAddress(from: ownerAddress),
                contractAddress: try tronHexAddress(from: contractAddress),
                functionSelector: "balanceOf(address)",
                parameter: try abiEncodedAddressParameter(from: ownerAddress),
                visible: false
            )

            request.httpBody = try JSONEncoder().encode(body)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<BigUInt> { data in
            let response = try JSONDecoder().decode(
                TronGridTriggerConstantContractResponse.self,
                from: data
            )

            guard response.result.result != false else {
                throw TronGridOperationFactoryError.contractCallFailed(response.result.message)
            }

            return response.balance
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    // MARK: - Phase 2 (send/transfer)

    func createNativeTransferBuildOperation(
        ownerAddress: AccountAddress,
        toAddress: AccountAddress,
        amountInPlank: BigUInt
    ) -> BaseOperation<TronGridUnsignedTransaction> {
        let url = baseUrl.appendingPathComponent("wallet/createtransaction")

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let body = CreateTransactionRequest(
                ownerAddress: try tronHexAddress(from: ownerAddress),
                toAddress: try tronHexAddress(from: toAddress),
                amount: try requireUInt64(amountInPlank),
                visible: false
            )

            request.httpBody = try JSONEncoder().encode(body)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<TronGridUnsignedTransaction> { data in
            let response = try JSONDecoder().decode(TronGridCreateTransactionResponse.self, from: data)

            guard let transaction = response.transaction else {
                throw TronGridOperationFactoryError.buildTransactionFailed(response.error)
            }

            return transaction
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTrc20TransferBuildOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress,
        toAddress: AccountAddress,
        amountInPlank: BigUInt,
        feeLimitInSun: BigUInt
    ) -> BaseOperation<TronGridUnsignedTransaction> {
        let url = baseUrl.appendingPathComponent("wallet/triggersmartcontract")

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let parameter = try abiEncodedAddressParameter(from: toAddress) +
                (try abiEncodedUInt256Parameter(from: amountInPlank))

            let body = TriggerSmartContractRequest(
                ownerAddress: try tronHexAddress(from: ownerAddress),
                contractAddress: try tronHexAddress(from: contractAddress),
                functionSelector: "transfer(address,uint256)",
                parameter: parameter,
                feeLimit: try requireUInt64(feeLimitInSun),
                visible: false
            )

            request.httpBody = try JSONEncoder().encode(body)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<TronGridUnsignedTransaction> { data in
            let response = try JSONDecoder().decode(TronGridTriggerSmartContractResponse.self, from: data)

            guard response.result.result == true, let transaction = response.transaction else {
                throw TronGridOperationFactoryError.buildTransactionFailed(response.result.message)
            }

            return transaction
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTrc20TransferEnergyEstimateOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress,
        toAddress: AccountAddress,
        amountInPlank: BigUInt
    ) -> BaseOperation<Int> {
        let url = baseUrl.appendingPathComponent("wallet/triggerconstantcontract")

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let parameter = try abiEncodedAddressParameter(from: toAddress) +
                (try abiEncodedUInt256Parameter(from: amountInPlank))

            let body = TriggerConstantContractRequest(
                ownerAddress: try tronHexAddress(from: ownerAddress),
                contractAddress: try tronHexAddress(from: contractAddress),
                functionSelector: "transfer(address,uint256)",
                parameter: parameter,
                visible: false
            )

            request.httpBody = try JSONEncoder().encode(body)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<Int> { data in
            let response = try JSONDecoder().decode(
                TronGridTriggerConstantContractResponse.self,
                from: data
            )

            guard response.result.result != false else {
                throw TronGridOperationFactoryError.contractCallFailed(response.result.message)
            }

            // Absent only in the (never-expected-here) case the node couldn't simulate execution
            // at all despite `result.result == true`; treated as zero extra energy needed rather
            // than failing the whole fee estimate outright.
            return response.energyUsed ?? 0
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createBroadcastOperation(
        transaction: TronGridUnsignedTransaction,
        signatureHex: String
    ) -> BaseOperation<TronGridBroadcastResponse> {
        let url = baseUrl.appendingPathComponent("wallet/broadcasttransaction")

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let body = TronGridBroadcastRequest(transaction: transaction, signatureHex: signatureHex)
            request.httpBody = try JSONEncoder().encode(body)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<TronGridBroadcastResponse> { data in
            try JSONDecoder().decode(TronGridBroadcastResponse.self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createAccountResourceOperation(
        for address: AccountAddress
    ) -> BaseOperation<TronGridAccountResourceResponse> {
        let url = baseUrl.appendingPathComponent("wallet/getaccountresource")

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let body = AccountResourceRequest(address: try tronHexAddress(from: address), visible: false)
            request.httpBody = try JSONEncoder().encode(body)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<TronGridAccountResourceResponse> { data in
            try JSONDecoder().decode(TronGridAccountResourceResponse.self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createChainParametersOperation() -> BaseOperation<TronGridChainParametersResponse> {
        let url = baseUrl.appendingPathComponent("wallet/getchainparameters")

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            request.setValue(UserAgent.nova, forHTTPHeaderField: "User-Agent")
            return request
        }

        let resultFactory = AnyNetworkResultFactory<TronGridChainParametersResponse> { data in
            try JSONDecoder().decode(TronGridChainParametersResponse.self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
