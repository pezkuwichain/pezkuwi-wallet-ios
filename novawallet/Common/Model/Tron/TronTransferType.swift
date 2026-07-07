import Foundation

// Mirrors `Modules/Gifts/Common/EvmTransferType.swift`'s role for the Tron send path.
enum TronTransferType {
    case native
    case trc20(contractAddress: AccountAddress)

    var transactionSource: TransactionHistoryItemSource {
        switch self {
        case .native:
            return .tronNative
        case .trc20:
            return .tronAsset
        }
    }

    var callCodingPath: CallCodingPath {
        switch self {
        case .native:
            return .tronNativeTransfer
        case .trc20:
            return .trc20Transfer
        }
    }
}
