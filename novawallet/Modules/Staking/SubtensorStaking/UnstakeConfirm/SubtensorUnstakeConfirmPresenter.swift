import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class SubtensorUnstakeConfirmPresenter {
    weak var view: CollatorStakingConfirmViewProtocol?
    let wireframe: SubtensorUnstakeConfirmWireframeProtocol
    let interactor: SubtensorUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let position: SubtensorStakePosition
    let amount: Decimal
    let logger: LoggerProtocol

    private(set) var balance: AssetBalance?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var price: PriceData?
    /// Estimated TAO received from unstaking the input alpha amount on subnet.
    /// nil for root (1:1) and until AMM price arrives.
    private(set) var taoEstimate: Double?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorUnstakeConfirmInteractorInputProtocol,
        wireframe: SubtensorUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        position: SubtensorStakePosition,
        amount: Decimal,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.balanceViewModelFactory = balanceViewModelFactory
        self.position = position
        self.amount = amount
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - View model providers

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    private func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
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

    private func provideValidatorViewModel() {
        let address = (try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat))
            ?? position.hotkey.toHex()
        let displayName = position.validatorIdentity

        let icon = try? PolkadotIconGenerator().generateFromAccountId(position.hotkey)
        let imageViewModel: ImageViewModelProtocol? = icon.map { DrawableIconViewModel(icon: $0) }

        let viewModel = DisplayAddressViewModel(
            address: address,
            name: displayName,
            imageViewModel: imageViewModel
        )

        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideHintsViewModel() {
        var hints = [
            R.string(preferredLanguages: selectedLocale.rLanguages)
                .localizable.stakingSubtensorHintNoUnbonding()
        ]

        if let taoEstimate, position.netuid != SubtensorStakingConstants.rootNetuid {
            let formatted = String(format: "%.4f", taoEstimate)
            hints.append(R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUnstakeTaoReceived(formatted))
        }

        view?.didReceiveHints(viewModel: hints)
    }

    private func refreshFee() {
        fee = nil
        interactor.estimateFee()
        provideFeeViewModel()
    }

    private func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideValidatorViewModel()
        provideHintsViewModel()
    }

    private func presentOptions(for address: AccountAddress) {
        guard let view = view else { return }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

// MARK: - CollatorStakingConfirmPresenterProtocol

extension SubtensorUnstakeConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()
        interactor.setup()
        refreshFee()
    }

    func selectAccount() {
        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(
            using: chainAsset.chain.chainFormat
        ) else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        guard let address = try? position.hotkey.toAddress(
            using: chainAsset.chain.chainFormat
        ) else {
            return
        }

        presentOptions(for: address)
    }

    func confirm() {
        // Unstake amount is taken from this user-typed value (alpha for subnet,
        // TAO for root). Cap at the position size; the chain enforces the
        // same bound but failing fast here gives a better UX.
        let positionAmount = position.amount
        guard let amountInPlank = amount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            return
        }

        guard amountInPlank <= positionAmount else {
            if let view = view {
                wireframe.presentAmountTooHigh(from: view, locale: selectedLocale)
            }
            return
        }

        view?.didStartLoading()
        interactor.confirm()
    }
}

// MARK: - SubtensorUnstakeConfirmInteractorOutputProtocol

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakeConfirmInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(feeInfo):
            fee = feeInfo
            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive fee error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(model):
            wireframe.complete(
                on: view,
                sender: model.sender,
                locale: selectedLocale
            )
        case let .failure(error):
            applyCurrentState()
            refreshFee()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveAMMPrice(spotPrice: Double?, taoReserve _: UInt64, alphaInReserve _: UInt64) {
        if let spotPrice, spotPrice > 0 {
            // tao_received ≈ alpha_amount * spot_price (TAO per alpha)
            let alphaAmount = NSDecimalNumber(decimal: amount).doubleValue
            taoEstimate = alphaAmount * spotPrice
        }

        provideHintsViewModel()

        if !interactor.hasPendingExtrinsic {
            refreshFee()
        }
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        if let view = view {
            _ = wireframe.present(
                error: error,
                from: view,
                locale: selectedLocale
            )
        }
    }
}

// MARK: - Localizable

extension SubtensorUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
