import Foundation

// Mirrors `Common/Model/Evm/CallCodingPath+Evm.swift`'s role: a locally-invented, display/history
// only tag (not a real Tron protocol name) used to distinguish a persisted `TransactionHistoryItem`
// as a native TRX transfer vs a TRC20 `transfer` call, the same way `.evmNativeTransfer`/
// `.erc20Tranfer` are used for the EVM history items.
extension CallCodingPath {
    static var tronNativeTransfer: CallCodingPath {
        CallCodingPath(moduleName: "TronNative", callName: "Transfer")
    }

    var isTronNativeTransfer: Bool {
        let transfer = Self.tronNativeTransfer

        return moduleName == transfer.moduleName && callName == transfer.callName
    }

    // Deliberately reuses the EXACT SAME `moduleName`/`callName` as `.erc20Tranfer` (both are the
    // ABI-level `transfer(address,uint256)` selector, which is identical for TRC20 and ERC20 -
    // Tron's TVM is EVM-bytecode-compatible). This is intentional, not an accidental collision: it
    // means a persisted Tron TRC20 transfer's `callPath` already satisfies
    // `CallCodingPath.isERC20Transfer` / `CallCodingPath.isTransfer` and is already included in
    // `NSPredicate.filterTransferTransactions()`'s existing `.erc20Tranfer` entry, without needing
    // its own separate predicate wiring. This is safe because every place that actually
    // distinguishes chain family also checks `TransactionHistoryItem.source`
    // (`.evmAsset` vs `.tronAsset`) alongside `callPath` - see e.g.
    // `TransactionHistoryPhishingFilter`'s `source == .evmAsset && callPath.isERC20Transfer` guard.
    static var trc20Transfer: CallCodingPath {
        CallCodingPath(moduleName: ERC20TransferEvent.tokenType, callName: ERC20TransferEvent.name)
    }
}
