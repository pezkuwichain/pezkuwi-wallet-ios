import Foundation

enum AssetListGroupModelComparator {
    static func by<T>(
        _ keyPath: KeyPath<T, Decimal>,
        _ lhs: T,
        _ rhs: T
    ) -> Bool? {
        compare(lhs: lhs, rhs: rhs, by: keyPath, zeroValue: 0)
    }

    // Explicit default ordering for the main asset list - kept identical to
    // TokenSorting.kt's mainTokensFirstAscendingOrder on Android. Symbols not
    // listed here fall through to pure alphabetical ordering.
    private static let symbolPriorityOrder: [String: UInt8] = [
        "HEZ": 0,
        "PEZ": 1,
        "USDT": 2,
        "DOT": 3,
        "KSM": 4,
        "USDC": 5,
        "BTC": 6,
        "ETH": 7,
        "BNB": 8,
        "TRX": 9,
        "AVAX": 10,
        "LINK": 11,
        "UNI": 12,
        "TAO": 13
    ]

    static func defaultComparator(
        lhs: AssetListAssetGroupModel,
        rhs: AssetListAssetGroupModel
    ) -> Bool {
        let lhsSymbolPriority = symbolPriorityOrder[lhs.multichainToken.symbol]
        let rhsSymbolPriority = symbolPriorityOrder[rhs.multichainToken.symbol]

        if let lhsSymbolPriority, let rhsSymbolPriority {
            return lhsSymbolPriority < rhsSymbolPriority
        } else if lhsSymbolPriority != nil {
            return true
        } else if rhsSymbolPriority != nil {
            return false
        }

        return lhs.multichainToken.symbol.lexicographicallyPrecedes(rhs.multichainToken.symbol)
    }

    static func compare<T, V: Comparable>(
        lhs: T,
        rhs: T,
        by keypath: KeyPath<T, V>,
        zeroValue: V
    ) -> Bool? {
        if lhs[keyPath: keypath] > zeroValue, rhs[keyPath: keypath] > zeroValue {
            return lhs[keyPath: keypath] > rhs[keyPath: keypath]
        } else if lhs[keyPath: keypath] > zeroValue {
            return true
        } else if rhs[keyPath: keypath] > zeroValue {
            return false
        } else {
            return nil
        }
    }
}
