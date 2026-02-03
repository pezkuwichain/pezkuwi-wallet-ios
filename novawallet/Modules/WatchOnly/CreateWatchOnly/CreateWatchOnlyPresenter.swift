import Foundation
import Foundation_iOS
import SubstrateSdk

final class CreateWatchOnlyPresenter {
    weak var view: CreateWatchOnlyViewProtocol?
    let wireframe: CreateWatchOnlyWireframeProtocol
    let interactor: CreateWatchOnlyInteractorInputProtocol
    let logger: LoggerProtocol

    private var partialSubstrateAddress: AccountAddress?
    private var partialEvmAddress: AccountAddress?
    private var partialNickname: String?
    private var demoWalletPreset: WatchOnlyWallet?

    private var termsAccepted: Bool = false

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    init(
        interactor: CreateWatchOnlyInteractorInputProtocol,
        wireframe: CreateWatchOnlyWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }
}

// MARK: - Private

private extension CreateWatchOnlyPresenter {
    func performWalletCreation() {
        guard let name = partialNickname else {
            return
        }

        let substrateAddressEmpty = (partialSubstrateAddress ?? "").isEmpty
        if !substrateAddressEmpty, getSubstrateAccountId() == nil {
            let languages = view?.selectedLocale.rLanguages ?? []
            wireframe.present(
                message: R.string(preferredLanguages: languages).localizable.commonInvalidSubstrateAddress(),
                title: R.string(preferredLanguages: languages).localizable.commonErrorGeneralTitle(),
                closeAction: R.string(preferredLanguages: languages).localizable.commonClose(),
                from: view
            )

            return
        }

        let substrateAddress = !substrateAddressEmpty ? partialSubstrateAddress : nil

        let evmAddressEmpty = (partialEvmAddress ?? "").isEmpty
        if !evmAddressEmpty, getEVMAccountId() == nil {
            let languages = view?.selectedLocale.rLanguages ?? []
            wireframe.present(
                message: R.string(preferredLanguages: languages).localizable.commonInvalidEvmAddress(),
                title: R.string(preferredLanguages: languages).localizable.commonErrorGeneralTitle(),
                closeAction: R.string(preferredLanguages: languages).localizable.commonClose(),
                from: view
            )
            return
        }

        let evmAddress = !evmAddressEmpty ? partialEvmAddress : nil

        let wallet = WatchOnlyWallet(name: name, substrateAddress: substrateAddress, evmAddress: evmAddress)
        interactor.save(wallet: wallet)
    }

    func getSubstrateAccountId() -> AccountId? {
        try? partialSubstrateAddress?.toSubstrateAccountId()
    }

    func getEVMAccountId() -> AccountId? {
        try? partialEvmAddress?.toEthereumAccountId()
    }

    func provideSubstrateAddressStateViewModel() {
        if
            let accountId = getSubstrateAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveSubstrateAddressState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveSubstrateAddressState(viewModel: viewModel)
        }
    }

    func provideSubstrateInputViewModel(enabled: Bool) {
        let value = partialSubstrateAddress ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(
            for: value,
            enabled: enabled
        )

        view?.didReceiveSubstrateAddressInput(viewModel: inputViewModel)
    }

    func provideEVMAddressStateViewModel() {
        if
            let accountId = getEVMAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveEVMAddressState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveEVMAddressState(viewModel: viewModel)
        }
    }

    func provideEVMInputViewModel(enabled: Bool) {
        let value = partialEvmAddress ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(
            for: value,
            enabled: enabled
        )

        view?.didReceiveEVMAddressInput(viewModel: inputViewModel)
    }

    func provideWalletNicknameViewModel(enabled: Bool) {
        let value = partialNickname ?? ""

        let inputViewModel = InputViewModel.createNicknameInputViewModel(
            for: value,
            enabled: enabled
        )

        view?.didReceiveNickname(viewModel: inputViewModel)
    }

    func provideFieldsViewModels(enabled: Bool = true) {
        provideWalletNicknameViewModel(enabled: enabled)
        provideSubstrateAddressStateViewModel()
        provideSubstrateInputViewModel(enabled: enabled)
        provideEVMAddressStateViewModel()
        provideEVMInputViewModel(enabled: enabled)
    }
}

// MARK: - CreateWatchOnlyPresenterProtocol

extension CreateWatchOnlyPresenter: CreateWatchOnlyPresenterProtocol {
    func setup() {
        provideFieldsViewModels()

        interactor.setup()
    }

    func performContinue() {
        wireframe.showScamAlert(
            from: view,
            delegate: self
        )
    }

    func performSubstrateScan() {
        wireframe.showAddressScan(
            from: view,
            delegate: self,
            context: NSNumber(value: true)
        )
    }

    func performEVMScan() {
        wireframe.showAddressScan(
            from: view,
            delegate: self,
            context: NSNumber(value: false)
        )
    }

    func updateWalletNickname(_ partialNickname: String) {
        self.partialNickname = partialNickname
    }

    func updateSubstrateAddress(_ partialAddress: String) {
        partialSubstrateAddress = partialAddress

        provideSubstrateAddressStateViewModel()
    }

    func updateEVMAddress(_ partialAddress: String) {
        partialEvmAddress = partialAddress

        provideEVMAddressStateViewModel()
    }

    func selectMode(for modeIndex: Int) {
        guard let mode = Mode(rawValue: modeIndex) else { return }

        switch mode {
        case .custom:
            partialNickname = ""
            partialSubstrateAddress = ""
            partialEvmAddress = ""

            provideFieldsViewModels(enabled: true)
        case .demo:
            guard let demoWalletPreset else { return }

            partialNickname = demoWalletPreset.name
            partialSubstrateAddress = demoWalletPreset.substrateAddress
            partialEvmAddress = demoWalletPreset.evmAddress

            provideFieldsViewModels(enabled: false)
        }
    }

    func toggleTermsCheckbox() {
        termsAccepted.toggle()

        view?.didReceiveTerms(accepted: termsAccepted)
    }
}

// MARK: - CreateWatchOnlyInteractorOutputProtocol

extension CreateWatchOnlyPresenter: CreateWatchOnlyInteractorOutputProtocol {
    func didReceiveDemoPreset(wallet: WatchOnlyWallet) {
        demoWalletPreset = wallet
    }

    func didCreateWallet() {
        wireframe.proceed(from: view)
    }

    func didFailWalletCreation(with error: Error) {
        _ = wireframe.present(error: error, from: view, locale: view?.selectedLocale)
        logger.error("Did receiver error: \(error)")
    }
}

// MARK: - AddressScanDelegate

extension CreateWatchOnlyPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context: AnyObject?) {
        wireframe.hideAddressScan(from: view)

        guard let isSubstrate = (context as? NSNumber)?.boolValue else {
            return
        }

        if isSubstrate {
            partialSubstrateAddress = address

            provideSubstrateAddressStateViewModel()
            provideSubstrateInputViewModel(enabled: true)
        } else {
            partialEvmAddress = address

            provideEVMAddressStateViewModel()
            provideEVMInputViewModel(enabled: true)
        }
    }
}

// MARK: - WOScamAlertSheetDelegate

extension CreateWatchOnlyPresenter: WOScamAlertSheetDelegate {
    func woScamAlertSheetDidCancel() {}

    func woScamAlertSheetDidConfirm() {
        performWalletCreation()
    }
}

private extension CreateWatchOnlyPresenter {
    enum Mode: Int {
        case custom = 0
        case demo
    }
}
