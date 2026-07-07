import Foundation
import Operation_iOS
import BigInt

enum TronGridOperationFactoryError: Error {
    case invalidAddress
    case invalidContractAddress
    case contractCallFailed(String?)
}

protocol TronGridOperationFactoryProtocol {
    func createNativeBalanceOperation(for address: AccountAddress) -> BaseOperation<BigUInt>

    func createTrc20BalanceOperation(
        ownerAddress: AccountAddress,
        contractAddress: AccountAddress
    ) -> BaseOperation<BigUInt>
}

/// Standalone REST client for TronGrid (https://api.trongrid.io), mirroring the
/// `Common/Network/Etherscan/` request/response factory style. Tron is not JSON-RPC/EVM-compatible
/// at the transport layer, so this deliberately does not go through `ChainRegistry`'s
/// `ConnectionPool`/`JSONRPCEngine` machinery used for Substrate and EVM chains - see
/// `Common/Model/Tron/ChainModel+Tron.swift` for the rationale.
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
}
