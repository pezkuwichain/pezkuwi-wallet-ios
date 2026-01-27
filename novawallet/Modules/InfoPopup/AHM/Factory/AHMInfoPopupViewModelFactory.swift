import Foundation
import BigInt

protocol AHMInfoPopupViewModelFactoryProtocol {
    func createViewModel(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        bannerState: BannersState,
        locale: Locale
    ) -> InfoPopupViewModel
}

final class AHMInfoPopupViewModelFactory {
    private let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let dateFormatter = DateFormatter.fullDate

    init(assetFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()) {
        self.assetFormatterFactory = assetFormatterFactory
    }
}

// MARK: - Private

private extension AHMInfoPopupViewModelFactory {
    func createTitle(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        locale: Locale
    ) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(info.timestamp))
        let sourceAsset = sourceChain.asset(for: info.sourceData.assetId)
        let tokenSymbol = sourceAsset?.symbol ?? ""

        if info.migrationInProgress {
            return R.string(preferredLanguages: locale.rLanguages)
                .localizable.ahmInfoInProgressTitle(
                    dateFormatter.value(for: locale).string(from: date),
                    tokenSymbol,
                    destinationChain.name
                )
        } else {
            return R.string(preferredLanguages: locale.rLanguages)
                .localizable.ahmInfoTitle(
                    dateFormatter.value(for: locale).string(from: date),
                    tokenSymbol,
                    destinationChain.name
                )
        }
    }

    func createFeatures(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        locale: Locale
    ) -> [InfoPopupViewModel.Feature] {
        var features: [InfoPopupViewModel.Feature] = []

        guard
            let sourceAsset = sourceChain.asset(for: info.sourceData.assetId),
            let destinationAsset = destinationChain.asset(for: info.destinationData.assetId)
        else {
            return features
        }

        // Min balance reduction
        let minBalanceReduction = calculateReduction(
            from: info.sourceData.minBalance,
            to: info.destinationData.minBalance
        )

        let sourceMinBalance = formatBalance(
            info.sourceData.minBalance,
            asset: sourceAsset,
            locale: locale
        )
        let destMinBalance = formatBalance(
            info.destinationData.minBalance,
            asset: destinationAsset,
            locale: locale
        )

        features.append(
            InfoPopupViewModel.Feature(
                emoji: "👛",
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoFeatureMinBalance(
                        minBalanceReduction,
                        sourceMinBalance,
                        destMinBalance
                    )
            )
        )

        // Fee reduction
        let feeReduction = calculateReduction(
            from: info.sourceData.averageFee,
            to: info.destinationData.averageFee
        )

        let sourceFee = formatBalance(
            info.sourceData.averageFee,
            asset: sourceAsset,
            locale: locale
        )
        let destFee = formatBalance(
            info.destinationData.averageFee,
            asset: destinationAsset,
            locale: locale
        )

        features.append(
            InfoPopupViewModel.Feature(
                emoji: "💸",
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoFeatureFees(
                        feeReduction,
                        sourceFee,
                        destFee
                    )
            )
        )

        // More tokens
        let tokensList = info.newTokenNames.joined(with: .commaSpace)
        features.append(
            InfoPopupViewModel.Feature(
                emoji: "🪙",
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoFeatureTokens(tokensList)
            )
        )

        // Pay fees in any token
        features.append(
            InfoPopupViewModel.Feature(
                emoji: "🧾",
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoFeaturePayFees()
            )
        )

        // Unified access
        features.append(
            InfoPopupViewModel.Feature(
                emoji: "🗂️",
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoFeatureUnified(sourceAsset.symbol)
            )
        )

        return features
    }

    func createInfoItems(
        sourceChain: ChainModel,
        locale: Locale
    ) -> [InfoPopupViewModel.InfoItem] {
        [
            InfoPopupViewModel.InfoItem(
                icon: .history,
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoHistoryInfo(sourceChain.name)
            ),
            InfoPopupViewModel.InfoItem(
                icon: .migration,
                text: R.string(preferredLanguages: locale.rLanguages)
                    .localizable.ahmInfoMigrationInfo()
            )
        ]
    }

    func calculateReduction(
        from source: BigUInt,
        to destination: BigUInt
    ) -> Int {
        guard destination > 0 else { return 0 }
        return Int(source / destination)
    }

    func formatBalance(
        _ value: BigUInt,
        asset: AssetModel,
        locale: Locale
    ) -> String {
        let assetInfo = asset.displayInfo
        let formatter = assetFormatterFactory.createTokenFormatter(
            for: assetInfo,
            roundingMode: .down
        )

        return formatter
            .value(for: locale)
            .stringFromDecimal(value.decimal(assetInfo: assetInfo)) ?? ""
    }
}

// MARK: - AHMInfoPopupViewModelFactoryProtocol

extension AHMInfoPopupViewModelFactory: AHMInfoPopupViewModelFactoryProtocol {
    func createViewModel(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        bannerState: BannersState,
        locale: Locale
    ) -> InfoPopupViewModel {
        let title = createTitle(
            from: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            locale: locale
        )

        let features = createFeatures(
            from: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            locale: locale
        )

        let infoItems = createInfoItems(
            sourceChain: sourceChain,
            locale: locale
        )

        return InfoPopupViewModel(
            bannerState: bannerState,
            title: title,
            subtitle: R.string(preferredLanguages: locale.rLanguages)
                .localizable.ahmInfoSubtitle(),
            features: features,
            infoItems: infoItems,
            additionalInfo: nil,
            mainActionTitle: R.string(preferredLanguages: locale.rLanguages)
                .localizable.commonGotIt(),
            skipActionTitle: nil,
            learnMoreTitle: R.string(preferredLanguages: locale.rLanguages)
                .localizable.commonLearnMore()
        )
    }
}
