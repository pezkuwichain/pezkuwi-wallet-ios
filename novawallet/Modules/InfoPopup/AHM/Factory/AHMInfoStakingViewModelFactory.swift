import Foundation
import Foundation_iOS

protocol AHMInfoStakingViewModelFactoryProtocol {
    func createStakingDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model
}

final class AHMInfoStakingViewModelFactory {
    private let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.fullDate) {
        self.dateFormatter = dateFormatter
    }
}

extension AHMInfoStakingViewModelFactory: AHMInfoStakingViewModelFactoryProtocol {
    func createStakingDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model {
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

        return AHMAlertView.Model(
            title: title,
            message: nil,
            learnMore: learnMoreModel,
            actionTitle: nil
        )
    }
}
