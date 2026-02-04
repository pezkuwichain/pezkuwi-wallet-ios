import Foundation

protocol InlinableAlertViewModelFactoryProtocol {
    func createWOAssetListAlertViewModel(for locale: Locale) -> InlinableAlertView.Model
}

final class InlinableAlertViewModelFactory {}

extension InlinableAlertViewModelFactory: InlinableAlertViewModelFactoryProtocol {
    func createWOAssetListAlertViewModel(for locale: Locale) -> InlinableAlertView.Model {
        let localizedStrings = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable

        let title = localizedStrings.inlinableAlertWoMessage()

        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: localizedStrings.commonLearnMore()
        )

        return InlinableAlertView.Model(
            type: .watchOnlyAssetList,
            title: title,
            message: nil,
            learnMore: learnMoreModel,
            actionTitle: nil,
            icon: R.image.iconWarningFilled(),
            showCloseButton: false
        )
    }
}
