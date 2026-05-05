import Foundation
import Foundation_iOS
import BigInt
import SubstrateSdk

final class SubtensorUnstakeSetupPresenter {
    weak var view: SubtensorUnstakeSetupViewProtocol?
    let interactor: SubtensorUnstakeSetupInteractorInputProtocol
    let wireframe: SubtensorUnstakeSetupWireframeProtocol

    let chainAsset: ChainAsset
    let position: SubtensorStakePosition
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var price: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var inputResult: AmountInputResult?

    init(
        interactor: SubtensorUnstakeSetupInteractorInputProtocol,
        wireframe: SubtensorUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        position: SubtensorStakePosition,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.position = position
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
    }

    private var selectedLocale: Locale {
        localizationManager.selectedLocale
    }

    private func positionDecimal() -> Decimal {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        return Decimal.fromSubstrateAmount(position.amount, precision: precision) ?? 0
    }

    private func availableForMax() -> Decimal {
        positionDecimal()
    }

    private func currentInputAmount() -> Decimal {
        inputResult?.absoluteValue(from: availableForMax()) ?? 0
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: availableForMax())
        let viewModel = balanceViewModelFactory
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideAssetViewModel() {
        let positionAmount = positionDecimal()
        let inputAmount = currentInputAmount()
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: positionAmount,
            priceData: price
        ).value(for: selectedLocale)
        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    private func providePositionViewModel() {
        let positionAmount = positionDecimal()
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            positionAmount,
            priceData: price
        ).value(for: selectedLocale)
        view?.didReceivePosition(viewModel: viewModel)
    }

    private func provideValidatorViewModel() {
        let address = (try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat))
            ?? position.hotkey.toHex()

        let displayName = position.validatorIdentity ?? SubtensorValidatorCellViewModelFactory.shorten(address: address)

        let imageViewModel: ImageViewModelProtocol?
        if let icon = try? PolkadotIconGenerator().generateFromAccountId(position.hotkey) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        let viewModel = AccountDetailsSelectionViewModel(
            displayAddress: DisplayAddressViewModel(
                address: address,
                name: displayName,
                imageViewModel: imageViewModel
            ),
            details: nil
        )

        view?.didReceiveValidator(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { fee in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }
            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }
        view?.didReceiveFee(viewModel: viewModel)
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        provideValidatorViewModel()
        providePositionViewModel()
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }
        provideAssetViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAmountInputViewModel()
        provideAssetViewModel()
    }

    func proceed() {
        let amount = currentInputAmount()
        guard amount > 0 else { return }

        wireframe.showConfirm(
            from: view,
            chainAsset: chainAsset,
            position: position,
            amount: amount
        )
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.price = price
        provideAssetViewModel()
        providePositionViewModel()
        provideFeeViewModel()
    }

    func didReceive(fee: ExtrinsicFeeProtocol?) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorUnstakeSetup: interactor error — \(error.localizedDescription)")
        wireframe.showError(from: view, message: error.localizedDescription)
    }
}
