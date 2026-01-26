import Foundation

final class InfoPopupContentBuilder {
    private var bannerDomain: Banners.Domain?
    private var title: ((Locale) -> String)?
    private var subtitle: ((Locale) -> String)?
    private var features: ((Locale) -> [InfoPopupContent.Feature])?
    private var additionalInfo: ((Locale) -> String)?
    private var mainActionTitle: ((Locale) -> String)?
    private var skipActionTitle: ((Locale) -> String)?
    private var learnMoreURL: URL?

    @discardableResult
    func with(bannerDomain: Banners.Domain?) -> Self {
        self.bannerDomain = bannerDomain
        return self
    }

    @discardableResult
    func with(title: @escaping (Locale) -> String) -> Self {
        self.title = title
        return self
    }

    @discardableResult
    func with(subtitle: @escaping (Locale) -> String) -> Self {
        self.subtitle = subtitle
        return self
    }

    @discardableResult
    func with(features: @escaping (Locale) -> [InfoPopupContent.Feature]) -> Self {
        self.features = features
        return self
    }

    @discardableResult
    func with(additionalInfo: @escaping (Locale) -> String) -> Self {
        self.additionalInfo = additionalInfo
        return self
    }

    @discardableResult
    func with(mainActionTitle: @escaping (Locale) -> String) -> Self {
        self.mainActionTitle = mainActionTitle
        return self
    }

    @discardableResult
    func with(skipActionTitle: @escaping (Locale) -> String) -> Self {
        self.skipActionTitle = skipActionTitle
        return self
    }

    @discardableResult
    func with(learnMoreURL: URL?) -> Self {
        self.learnMoreURL = learnMoreURL
        return self
    }

    func build() -> InfoPopupLocalizedContent? {
        guard
            let title,
            let features,
            let mainActionTitle
        else {
            return nil
        }

        return InfoPopupLocalizedContent(
            bannerDomain: bannerDomain,
            title: title,
            subtitle: subtitle,
            features: features,
            additionalInfo: additionalInfo,
            mainActionTitle: mainActionTitle,
            skipActionTitle: skipActionTitle,
            learnMoreURL: learnMoreURL
        )
    }
}
