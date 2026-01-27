import Foundation

protocol ASMInfoPopupViewModelFactoryProtocol {
    func createViewModel(
        bannerState: BannersState,
        locale: Locale
    ) -> InfoPopupViewModel
}

final class ASMInfoPopupViewModelFactory {}

private extension ASMInfoPopupViewModelFactory {
    func createFeatures(locale: Locale) -> [InfoPopupViewModel.Feature] {
        let languages = locale.rLanguages

        return [
            InfoPopupViewModel.Feature(
                emoji: "🤩",
                text: R.string(preferredLanguages: languages)
                    .localizable.asmInfoFeatureUi()
            ),
            InfoPopupViewModel.Feature(
                emoji: "🧊",
                text: R.string(preferredLanguages: languages)
                    .localizable.asmInfoFeatureLiquidGlass()
            ),
            InfoPopupViewModel.Feature(
                emoji: "🛡️",
                text: R.string(preferredLanguages: languages)
                    .localizable.asmInfoFeatureSecurity()
            ),
            InfoPopupViewModel.Feature(
                emoji: "✨",
                text: R.string(preferredLanguages: languages)
                    .localizable.asmInfoFeatureMore()
            )
        ]
    }

    func createInfoItems(locale: Locale) -> [InfoPopupViewModel.InfoItem] {
        [
            InfoPopupViewModel.InfoItem(
                icon: .migration,
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.asmInfoAdditionalInfo()
            )
        ]
    }
}

extension ASMInfoPopupViewModelFactory: ASMInfoPopupViewModelFactoryProtocol {
    func createViewModel(
        bannerState: BannersState,
        locale: Locale
    ) -> InfoPopupViewModel {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages)
            .localizable.asmInfoTitle()

        let subtitle = R.string(preferredLanguages: languages)
            .localizable.asmInfoSubtitle()

        let features = createFeatures(locale: locale)

        let additionalInfo = R.string(preferredLanguages: languages)
            .localizable.asmInfoAdditionalInfo()

        let mainActionTitle = R.string(preferredLanguages: languages)
            .localizable.asmInfoMainAction()

        let skipActionTitle = R.string(preferredLanguages: languages)
            .localizable.commonSkip()

        let learnMoreTitle = R.string(preferredLanguages: languages)
            .localizable.commonLearnMore()

        return InfoPopupViewModel(
            bannerState: bannerState,
            title: title,
            subtitle: subtitle,
            features: features,
            infoItems: createInfoItems(locale: locale),
            additionalInfo: nil,
            mainActionTitle: mainActionTitle,
            skipActionTitle: skipActionTitle,
            learnMoreTitle: learnMoreTitle
        )
    }
}
