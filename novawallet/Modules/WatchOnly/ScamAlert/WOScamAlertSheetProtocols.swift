protocol WOScamAlertSheetDelegate: AnyObject {
    func woScamAlertSheetDidCancel()
    func woScamAlertSheetDidConfirm()
}

protocol WOScamAlertSheetViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: WOScamAlertSheetViewModel)
    func didStartTimer(totalSeconds: Int)
    func didUpdateTimer(remainingSeconds: Int)
    func didFinishTimer()
}

protocol WOScamAlertSheetPresenterProtocol: AnyObject {
    func setup()
    func cancel()
    func confirm()
    func openSupportEmail()
}

protocol WOScamAlertSheetWireframeProtocol: AnyObject {
    func complete(from view: WOScamAlertSheetViewProtocol?, confirmed: Bool)
    func openEmail()
}
