import Foundation

class TransferConfirmWireframe: TransferConfirmWireframeProtocol {}

final class EvmTransferConfirmWireframe: TransferConfirmWireframe, EvmValidationErrorPresentable {}

// See the matching comment on `TronOnChainTransferSetupWireframe`: no extra `...Presentable`
// conformance needed for the Tron send path.
final class TronTransferConfirmWireframe: TransferConfirmWireframe {}
