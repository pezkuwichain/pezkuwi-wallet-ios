import Foundation
import BigInt

/// Mirrors `EvmTransactionFeeProxy`'s cache-by-reuse-identifier + delegate-callback shape exactly,
/// just parameterized over `TronFeeModel` instead of `EvmFeeModel`.
protocol TronTransactionFeeProxyDelegate: AnyObject {
    func didReceiveTronFee(result: Result<TronFeeModel, Error>, for identifier: TransactionFeeId)
}

protocol TronTransactionFeeProxyProtocol: AnyObject {
    var delegate: TronTransactionFeeProxyDelegate? { get set }

    func estimateFee(
        using service: TronTransactionServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        type: TronTransferType,
        amount: BigUInt,
        recipient: AccountAddress
    )
}

final class TronTransactionFeeProxy: TransactionFeeProxy<TronFeeModel> {
    weak var delegate: TronTransactionFeeProxyDelegate?

    private func handle(result: Result<TronFeeModel, Error>, for stateKey: StateKey) {
        update(result: result, for: stateKey)

        delegate?.didReceiveTronFee(result: result, for: stateKey.reuseIdentifier)
    }
}

extension TronTransactionFeeProxy: TronTransactionFeeProxyProtocol {
    func estimateFee(
        using service: TronTransactionServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        type: TronTransferType,
        amount: BigUInt,
        recipient: AccountAddress
    ) {
        let stateKey = StateKey(reuseIdentifier: reuseIdentifier, chainAssetId: nil)

        if let state = getCachedState(for: stateKey) {
            if case let .loaded(result) = state {
                delegate?.didReceiveTronFee(result: result, for: reuseIdentifier)
            }

            return
        }

        setCachedState(.loading, for: stateKey)

        service.estimateFee(
            for: type,
            amount: amount,
            recipient: recipient,
            runningIn: .main
        ) { [weak self] result in
            self?.handle(result: result, for: stateKey)
        }
    }
}
