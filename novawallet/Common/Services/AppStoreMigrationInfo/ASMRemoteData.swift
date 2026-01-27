import Foundation

struct ASMRemoteData: Codable, Equatable {
    let bannerPath: Banners.Domain
    let migrationInProgress: Bool
    let newAppLink: URL
    let wikiURL: URL
}

extension ASMRemoteData {
    var cacheKey: String {
        newAppLink.absoluteString
    }
}
