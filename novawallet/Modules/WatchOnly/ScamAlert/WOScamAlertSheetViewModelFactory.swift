import Foundation
import UIKit

struct WOScamAlertSheetViewModel {
    let title: String
    let message: NSAttributedString
    let contact: NSAttributedString
    let cancelTitle: String
    let confirmTitle: String
}

protocol WOScamAlertSheetViewModelFactoryProtocol {
    func createViewModel(for locale: Locale) -> WOScamAlertSheetViewModel
}

final class WOScamAlertSheetViewModelFactory: WOScamAlertSheetViewModelFactoryProtocol {
    private let supportEmail: String

    init(supportEmail: String) {
        self.supportEmail = supportEmail
    }

    func createViewModel(for locale: Locale) -> WOScamAlertSheetViewModel {
        let languages = locale.rLanguages
        let localizedStrings = R.string(preferredLanguages: languages).localizable

        let message = NSAttributedString.coloredFontItems(
            [localizedStrings.watchOnlyScamAlertMessageHighlighted()],
            formattingClosure: { localizedStrings.watchOnlyScamAlertMessageFormat($0[0]) },
            color: R.color.colorTextPrimary()!,
            font: .regularSubheadline,
            defaultAttributes: [
                .font: UIFont.regularSubheadline,
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        let contact = NSAttributedString.coloredFontItems(
            [supportEmail],
            formattingClosure: { localizedStrings.watchOnlyScamAlertContactFormat($0[0]) },
            color: R.color.colorButtonTextAccent()!,
            font: .regularSubheadline,
            defaultAttributes: [
                .font: UIFont.regularSubheadline,
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        return WOScamAlertSheetViewModel(
            title: localizedStrings.watchOnlyScamAlertTitle(),
            message: message,
            contact: contact,
            cancelTitle: localizedStrings.commonCancel(),
            confirmTitle: localizedStrings.watchOnlyScamAlertConfirm()
        )
    }
}
