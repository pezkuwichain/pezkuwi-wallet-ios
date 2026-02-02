import Foundation
import Foundation_iOS

struct WOScamAlertSheetViewFactory {
    static func createView(
        delegate: WOScamAlertSheetDelegate,
        countdownDuration: Int = 8
    ) -> WOScamAlertSheetViewProtocol? {
        let wireframe = WOScamAlertSheetWireframe()
        wireframe.delegate = delegate

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = WOScamAlertSheetViewModelFactory()

        let presenter = WOScamAlertSheetPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            countdownDuration: countdownDuration
        )

        let view = WOScamAlertSheetViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
