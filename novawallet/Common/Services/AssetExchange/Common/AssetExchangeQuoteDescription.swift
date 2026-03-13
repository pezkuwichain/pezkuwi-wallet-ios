import Foundation

enum AssetExchangeQuoteDescription {
    static func getDescription(
        quote: AssetExchangeQuote,
        chainRegistry: ChainRegistryProtocol
    ) -> String {
        let edges = quote.route.items.map(\.edge)
        let pathDescription = AssetsExchangeGraphDescription.getDescriptionForPath(
            edges: edges,
            chainRegistry: chainRegistry
        )

        return "Calculated quote for path: \(pathDescription)"
    }
}
