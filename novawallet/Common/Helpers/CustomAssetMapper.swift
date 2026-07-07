import Foundation
import SubstrateSdk

struct CustomAssetMapper {
    struct ExtrasToValue<T> {
        let nativeHandler: () -> T
        let statemineHandler: (StatemineAssetExtras) -> T
        let ormlHandler: (OrmlTokenExtras) -> T
        let ormlHydrationEvmHandler: (OrmlTokenExtras) -> T
        let evmHandler: (AccountId) -> T
        let evmNativeHandler: () -> T
        let equilibriumHandler: (EquilibriumAssetExtras) -> T
    }

    struct TypeToValue<T> {
        let nativeHandler: () -> T
        let statemineHandler: () -> T
        let ormlHandler: () -> T
        let evmHandler: () -> T
        let ormlHydrationEvmHandler: () -> T
        let evmNativeHandler: () -> T
        let equilibriumHandler: () -> T
    }

    enum MapperError: Error {
        case unexpectedType(_ type: String?)
        case invalidJson(_ type: String?)
    }

    let type: String?
    let typeExtras: AssetTypeExtras?

    func mapAssetWithExtras<T>(_ handlers: ExtrasToValue<T>) throws -> T {
        let wrappedType: AssetType? = try type.map { value in
            if let typeValue = AssetType(rawValue: value) {
                return typeValue
            } else {
                throw MapperError.unexpectedType(type)
            }
        }

        switch wrappedType {
        case .statemine:
            guard let wrappedExtras = try? typeExtras?.map(to: StatemineAssetExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return handlers.statemineHandler(wrappedExtras)
        case .orml:
            guard let wrappedExtras = try? typeExtras?.map(to: OrmlTokenExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return handlers.ormlHandler(wrappedExtras)
        case .ormlHydrationEvm:
            guard let wrappedExtras = try? typeExtras?.map(to: OrmlTokenExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return handlers.ormlHandler(wrappedExtras)
        case .evmAsset:
            guard let contractAddress = typeExtras?.evmContractAddress else {
                throw MapperError.invalidJson(type)
            }

            let accountId = try contractAddress.toAccountId(using: .ethereum)

            return handlers.evmHandler(accountId)
        case .evmNative:
            return handlers.evmNativeHandler()
        case .equilibrium:
            guard let wrappedExtras = try? typeExtras?.map(to: EquilibriumAssetExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return handlers.equilibriumHandler(wrappedExtras)
        case .none:
            return handlers.nativeHandler()
        case .tronNative, .trc20:
            // Tron assets never flow through this mapper (or `WalletRemoteSubscription`/
            // `ChainRegistry` at all) - they're fetched via a standalone TronGrid REST poller
            // (see `Common/Network/TronGrid/`), since Tron has no substrate-style JSON-RPC.
            // Throwing here (rather than silently treating as native) makes that assumption
            // loudly visible if it's ever violated.
            throw MapperError.unexpectedType(type)
        }
    }

    func mapAsset<T>(_ handlers: TypeToValue<T>) throws -> T {
        let wrappedType: AssetType? = try type.map { value in
            if let typeValue = AssetType(rawValue: value) {
                return typeValue
            } else {
                throw MapperError.unexpectedType(type)
            }
        }

        switch wrappedType {
        case .statemine:
            return handlers.statemineHandler()
        case .orml:
            return handlers.ormlHandler()
        case .ormlHydrationEvm:
            return handlers.ormlHydrationEvmHandler()
        case .evmAsset:
            return handlers.evmHandler()
        case .evmNative:
            return handlers.evmNativeHandler()
        case .equilibrium:
            return handlers.equilibriumHandler()
        case .none:
            return handlers.nativeHandler()
        case .tronNative, .trc20:
            // See the matching comment in `mapAssetWithExtras` above.
            throw MapperError.unexpectedType(type)
        }
    }
}

extension CustomAssetMapper {
    func historyAssetId() throws -> String? {
        try mapAssetWithExtras(
            .init(
                nativeHandler: { nil },
                statemineHandler: { $0.assetId },
                ormlHandler: { $0.currencyIdScale },
                ormlHydrationEvmHandler: { $0.currencyIdScale },
                evmHandler: { try? $0.toAddress(using: .ethereum) },
                evmNativeHandler: { nil },
                equilibriumHandler: { String($0.assetId) }
            )
        )
    }

    func transfersEnabled() throws -> Bool {
        try mapAssetWithExtras(
            .init(
                nativeHandler: { true },
                statemineHandler: { _ in true },
                ormlHandler: { $0.transfersEnabled ?? true },
                ormlHydrationEvmHandler: { $0.transfersEnabled ?? true },
                evmHandler: { _ in true },
                evmNativeHandler: { true },
                equilibriumHandler: { $0.transfersEnabled ?? true }
            )
        )
    }
}
