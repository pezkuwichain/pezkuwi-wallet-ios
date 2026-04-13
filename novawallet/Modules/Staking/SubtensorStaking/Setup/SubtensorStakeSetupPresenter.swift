import Foundation
import Foundation_iOS
import BigInt
import SubstrateSdk

/// Presenter for the Subtensor stake setup screen. Owns:
///   - validator selection state
///   - amount input state (typed by user / Max button / accessory)
///   - cached fetched validators (used to populate the picker without a refetch)
///   - cached min-delegation runtime constant
///   - live `AssetBalance` + `PriceData` from the interactor
///
/// Binding uses Nova's `BalanceViewModelFactory` so the flow lines up with
/// parachain / Mythos staking. Max / percentage buttons are wired via
/// `AmountInputResult` so they can target a rate (e.g. 1.0) regardless of
/// the current absolute amount.
///
/// Phase A intentionally skips remote fee estimation: real extrinsic fee
/// quoting lands in Phase B alongside confirm / submit. Until then the
/// min-stake + balance rows still update live.
final class SubtensorStakeSetupPresenter {
    weak var view: SubtensorStakeSetupViewProtocol?
    let interactor: SubtensorStakeSetupInteractorInputProtocol
    let wireframe: SubtensorStakeSetupWireframeProtocol

    let chainAsset: ChainAsset
    let netuid: UInt16
    let walletName: String
    let validatorProvider: SubtensorValidatorProvider
    let cellViewModelFactory: SubtensorValidatorCellViewModelFactory
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var validators: [SubtensorValidator] = []
    private var minDelegationRao: BigUInt?
    private var selectedValidator: SubtensorValidator?

    private var assetBalance: AssetBalance?
    private var price: PriceData?
    private var inputResult: AmountInputResult?

    init(
        interactor: SubtensorStakeSetupInteractorInputProtocol,
        wireframe: SubtensorStakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        walletName: String,
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.walletName = walletName
        self.validatorProvider = validatorProvider
        self.cellViewModelFactory = cellViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
        self.netuid = netuid
    }

    // MARK: - Private helpers

    private var selectedLocale: Locale {
        localizationManager.selectedLocale
    }

    private func transferableInPlank() -> BigUInt {
        assetBalance?.transferable ?? 0
    }

    private func transferableBalance() -> Decimal {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        return Decimal.fromSubstrateAmount(
            transferableInPlank(),
            precision: precision
        ) ?? 0
    }

    /// Available amount for the Max button. Mirrors ParaStk's `balanceMinusFee()`
    /// but with `fee = 0` for Phase A. Phase B will subtract real fee + gas
    /// reserve once extrinsic fee quoting is wired.
    private func availableForMax() -> Decimal {
        // v1: reserve zero until fee estimation is wired in Phase B.
        transferableBalance()
    }

    private func currentInputAmount() -> Decimal {
        inputResult?.absoluteValue(from: availableForMax()) ?? 0
    }

    // MARK: - View bindings

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: availableForMax())

        let viewModel = balanceViewModelFactory
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideAssetViewModel() {
        let balanceDecimal = transferableBalance()
        let inputAmount = currentInputAmount()

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    private func provideMinStakeViewModel() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        let viewModel: BalanceViewModelProtocol? = minDelegationRao.flatMap { amount in
            guard let decimalAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: precision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                decimalAmount,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        // Phase A: no remote fee quoting. Show nil so the row spins a placeholder
        // instead of lying. Phase B wires real ExtrinsicFeeProxy.
        view?.didReceiveFee(viewModel: nil)
    }

    private func provideValidatorViewModel() {
        guard let validator = selectedValidator else {
            view?.didReceiveValidator(viewModel: nil)
            return
        }

        let displayName = (validator.identity?.isEmpty == false) ? validator.identity : nil

        let address = (try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat))
            ?? validator.hotkey.toHex()
        let shortName = displayName ?? SubtensorValidatorCellViewModelFactory.shorten(address: address)

        let imageViewModel: ImageViewModelProtocol?
        if let icon = try? PolkadotIconGenerator().generateFromAccountId(validator.hotkey) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        let viewModel = AccountDetailsSelectionViewModel(
            displayAddress: DisplayAddressViewModel(
                address: address,
                name: shortName,
                imageViewModel: imageViewModel
            ),
            details: nil
        )

        view?.didReceiveValidator(viewModel: viewModel)
    }
}

// MARK: - SubtensorStakeSetupPresenterProtocol

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupPresenterProtocol {
    func setup() {
        provideValidatorViewModel()
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func selectValidator() {
        wireframe.showValidatorPicker(
            from: view,
            netuid: netuid,
            prefetched: validators,
            validatorProvider: validatorProvider,
            cellViewModelFactory: cellViewModelFactory
        ) { [weak self] selected in
            self?.handleValidatorSelected(selected)
        }
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
        guard let validator = selectedValidator else { return }

        let amount = currentInputAmount()
        guard amount > 0 else { return }

        wireframe.showConfirm(
            from: view,
            chainAsset: chainAsset,
            validator: validator,
            amount: amount
        )
    }

    // MARK: - Private handlers

    private func handleValidatorSelected(_ validator: SubtensorValidator) {
        selectedValidator = validator
        provideValidatorViewModel()
    }
}

// MARK: - SubtensorStakeSetupInteractorOutputProtocol

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupInteractorOutputProtocol {
    func didReceive(validators: [SubtensorValidator]) {
        self.validators = validators
    }

    func didReceive(minDelegation: BigUInt) {
        minDelegationRao = minDelegation
        provideMinStakeViewModel()
    }

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance

        provideAssetViewModel()
        provideAmountInputViewModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price

        provideAssetViewModel()
        provideMinStakeViewModel()
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorStakeSetup: interactor error — \(error.localizedDescription)")
        wireframe.showError(from: view, message: error.localizedDescription)
    }
}
