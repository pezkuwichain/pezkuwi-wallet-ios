import Foundation

protocol InfoPopupViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: InfoPopupViewModel)
}

protocol InfoPopupPresenterProtocol: AnyObject {
    func setup()
    func actionMain()
    func actionSkip()
    func actionLearnMore()
}

protocol InfoPopupInteractorInputProtocol: AnyObject {
    func setup()
    func performMainAction()
    func performSkipAction()
}

protocol InfoPopupInteractorOutputProtocol: AnyObject {
    func didSetup()
    func didCompleteMainAction()
    func didCompleteSkipAction()
    func didReceive(error: Error)
}

protocol InfoPopupWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable {
    func complete(from view: InfoPopupViewProtocol?)
    func proceed(from view: InfoPopupViewProtocol?, action: InfoPopupAction?)
}
