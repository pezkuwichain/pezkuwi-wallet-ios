import Foundation

struct ASMRemoteData: Codable, Equatable {
    let bannerPath: Banners.Domain
    let migrationInProgress: Bool
    let newAppId: String
    let wikiURL: URL
}

extension ASMRemoteData {
    var cacheKey: String {
        newAppId
    }
}
