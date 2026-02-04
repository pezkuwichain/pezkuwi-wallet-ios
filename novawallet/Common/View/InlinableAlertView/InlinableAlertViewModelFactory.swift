import Foundation
import Foundation_iOS

protocol InlinableAlertViewModelFactoryProtocol {
    func createWOAssetListAlertViewModel(for locale: Locale) -> InlinableAlertView.Model

    func createStakingDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> InlinableAlertView.Model

    func createAssetDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> InlinableAlertView.Model
}

final class InlinableAlertViewModelFactory {
    private let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.fullDate) {
        self.dateFormatter = dateFormatter
    }
}

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

    func createStakingDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> InlinableAlertView.Model {
        let sourceChainAsset = ChainAsset(
            chain: info.sourceChain,
            asset: info.asset
        )
        let languages = locale.rLanguages

        let date = Date(timeIntervalSince1970: TimeInterval(info.info.timestamp))

        let formattedDate = dateFormatter
            .value(for: locale)
            .string(from: date)

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertStakingDetailsMessage(
            sourceChainAsset.chainAssetName,
            info.destinationChain.name,
            formattedDate
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonLearnMore()
        )

        return InlinableAlertView.Model(
            type: .ahmStakingDetails,
            title: title,
            message: nil,
            learnMore: learnMoreModel,
            actionTitle: nil,
            icon: R.image.iconInfoAccent()!,
            showCloseButton: true
        )
    }

    func createAssetDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> InlinableAlertView.Model {
        let languages = locale.rLanguages

        let date = Date(timeIntervalSince1970: TimeInterval(info.info.timestamp))

        let formattedDate = dateFormatter
            .value(for: locale)
            .string(from: date)

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertAssetDetailsTitle(
            info.asset.symbol,
            info.destinationChain.name
        )
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertAssetDetailsMessage(
            formattedDate,
            info.asset.symbol,
            info.destinationChain.name
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonLearnMore()
        )
        let actionTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertAssetDetailsAction(
            info.destinationChain.name
        )

        return InlinableAlertView.Model(
            type: .ahmAssetDetails,
            title: title,
            message: message,
            learnMore: learnMoreModel,
            actionTitle: actionTitle,
            icon: R.image.iconInfoAccent()!,
            showCloseButton: true
        )
    }
}
