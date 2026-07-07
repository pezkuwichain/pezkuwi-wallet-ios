import Foundation
import BigInt
import Operation_iOS

/// Mirrors `EvmTransferCommandFactory`'s role (translate a transfer-type + amount + recipient
/// into the actual on-the-wire transfer request), but returns a network operation rather than a
/// pure local builder-mutation: unlike EVM's local RLP encoding, an unsigned Tron transaction can
/// only be produced by asking a TronGrid node to build it (see `TronGridOperationFactory`'s
/// type-level doc comment for why this app never encodes Tron's protobuf `Transaction` itself).
final class TronTransferCommandFactory {
    let operationFactory: TronGridOperationFactoryProtocol

    init(operationFactory: TronGridOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }

    /// `feeLimitInSun` is only meaningful for `.trc20` (bounds the max TRX the network may burn
    /// for TVM energy while executing the call) - ignored for `.native`, which cannot burn energy.
    func buildTransferOperation(
        ownerAddress: AccountAddress,
        recipient: AccountAddress,
        amount: BigUInt,
        type: TronTransferType,
        feeLimitInSun: BigUInt
    ) -> BaseOperation<TronGridUnsignedTransaction> {
        switch type {
        case .native:
            return operationFactory.createNativeTransferBuildOperation(
                ownerAddress: ownerAddress,
                toAddress: recipient,
                amountInPlank: amount
            )
        case let .trc20(contractAddress):
            return operationFactory.createTrc20TransferBuildOperation(
                ownerAddress: ownerAddress,
                contractAddress: contractAddress,
                toAddress: recipient,
                amountInPlank: amount,
                feeLimitInSun: feeLimitInSun
            )
        }
    }
}
