import Foundation
import Foundation_iOS

/// Assembly for the self-contained Pezkuwi dashboard card module — mirrors
/// `Modules/Banners/Factory/BannersViewFactory.swift`'s embedding contract exactly (this module is
/// constructed once inside `AssetListViewFactory` and embedded as a single cell, the same way the
/// banners widget is).
struct PezkuwiDashboardViewFactory {
    static func createView(
        output: PezkuwiDashboardModuleOutputProtocol,
        inputOwner: PezkuwiDashboardModuleInputOwnerProtocol
    ) -> PezkuwiDashboardViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let repository = PezkuwiDashboardRepository(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: operationQueue
        )

        let interactor = PezkuwiDashboardInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let wireframe = PezkuwiDashboardWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = PezkuwiDashboardPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = PezkuwiDashboardViewController(presenter: presenter)

        presenter.view = view
        presenter.moduleOutput = output
        interactor.presenter = presenter

        inputOwner.pezkuwiDashboardModule = presenter

        return view
    }
}
