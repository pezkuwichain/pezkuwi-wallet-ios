import Foundation

protocol AHMInfoPopupInteractorOutputProtocol: AnyObject {
    func didReceive(
        info: AHMRemoteData,
        sourceChain: ChainModel?,
        destinationChain: ChainModel?
    )
    func didCompleteMainAction()
    func didCompleteSkipAction()
    func didReceive(error: Error)
}
