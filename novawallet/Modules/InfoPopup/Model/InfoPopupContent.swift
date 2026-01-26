import Foundation

struct InfoPopupContent {
    let bannerDomain: Banners.Domain?
    let title: String
    let subtitle: String?
    let features: [Feature]
    let additionalInfo: String?
    let mainActionTitle: String
    let skipActionTitle: String?
    let learnMoreURL: URL?

    struct Feature {
        let emoji: String
        let text: String
    }
}

extension InfoPopupContent {
    static func from(localized: InfoPopupLocalizedContent, locale: Locale) -> InfoPopupContent {
        InfoPopupContent(
            bannerDomain: localized.bannerDomain,
            title: localized.title(locale),
            subtitle: localized.subtitle?(locale),
            features: localized.features(locale).map { Feature(emoji: $0.emoji, text: $0.text) },
            additionalInfo: localized.additionalInfo?(locale),
            mainActionTitle: localized.mainActionTitle(locale),
            skipActionTitle: localized.skipActionTitle?(locale),
            learnMoreURL: localized.learnMoreURL
        )
    }
}

struct InfoPopupLocalizedContent {
    let bannerDomain: Banners.Domain?
    let title: (Locale) -> String
    let subtitle: ((Locale) -> String)?
    let features: (Locale) -> [InfoPopupContent.Feature]
    let additionalInfo: ((Locale) -> String)?
    let mainActionTitle: (Locale) -> String
    let skipActionTitle: ((Locale) -> String)?
    let learnMoreURL: URL?
}
