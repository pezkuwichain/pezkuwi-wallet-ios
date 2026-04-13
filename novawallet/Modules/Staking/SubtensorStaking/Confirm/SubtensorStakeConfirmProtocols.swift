import Foundation
import BigInt

protocol SubtensorStakeConfirmInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()
    func estimateFee()
    func confirm()
}

protocol SubtensorStakeConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveAMMPrice(spotPrice: Double?, taoReserve: UInt64, alphaInReserve: UInt64)
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveError(_ error: Error)
}

protocol SubtensorStakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    BaseErrorPresentable, AddressOptionsPresentable, FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    )
}
