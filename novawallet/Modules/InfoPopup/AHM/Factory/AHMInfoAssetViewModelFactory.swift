import Foundation
import Foundation_iOS

protocol AHMInfoAssetViewModelFactoryProtocol {
    func createAssetDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model
}

final class AHMInfoAssetViewModelFactory {
    private let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.fullDate) {
        self.dateFormatter = dateFormatter
    }
}

extension AHMInfoAssetViewModelFactory: AHMInfoAssetViewModelFactoryProtocol {
    func createAssetDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model {
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

        return AHMAlertView.Model(
            title: title,
            message: message,
            learnMore: learnMoreModel,
            actionTitle: actionTitle
        )
    }
}
