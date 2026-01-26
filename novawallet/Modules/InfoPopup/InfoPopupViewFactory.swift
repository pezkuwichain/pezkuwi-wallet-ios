import Foundation
import Foundation_iOS

struct InfoPopupViewFactory {
    static func createView(
        localizedContent: InfoPopupLocalizedContent,
        mainAction: InfoPopupAction? = nil,
        skipAction: InfoPopupAction? = nil
    ) -> InfoPopupViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let interactor = InfoPopupInteractor(
            localizedContent: localizedContent,
            localizationManager: localizationManager
        )

        let wireframe = InfoPopupWireframe()

        let presenter = InfoPopupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            mainAction: mainAction,
            skipAction: skipAction,
            localizationManager: localizationManager
        )

        let bannersModule: BannersViewProviderProtocol?

        if let bannerDomain = localizedContent.bannerDomain {
            bannersModule = BannersViewFactory.createView(
                domain: bannerDomain,
                output: presenter,
                inputOwner: presenter,
                locale: localizationManager.selectedLocale
            )
        } else {
            bannersModule = nil
        }

        let view = InfoPopupViewController(
            presenter: presenter,
            bannersViewProvider: bannersModule,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createView(
        content: InfoPopupContent,
        mainAction: InfoPopupAction? = nil,
        skipAction: InfoPopupAction? = nil
    ) -> InfoPopupViewProtocol? {
        let localizedContent = InfoPopupLocalizedContent(
            bannerDomain: content.bannerDomain,
            title: { _ in content.title },
            subtitle: content.subtitle.map { subtitle in { _ in subtitle } },
            features: { _ in content.features },
            additionalInfo: content.additionalInfo.map { info in { _ in info } },
            mainActionTitle: { _ in content.mainActionTitle },
            skipActionTitle: content.skipActionTitle.map { title in { _ in title } },
            learnMoreURL: content.learnMoreURL
        )

        return createView(
            localizedContent: localizedContent,
            mainAction: mainAction,
            skipAction: skipAction
        )
    }
}
