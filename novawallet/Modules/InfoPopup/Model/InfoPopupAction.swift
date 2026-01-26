import Foundation

enum InfoPopupAction {
    case url(URL)
    case deepLink(String)
    case custom(() -> Void)
}
