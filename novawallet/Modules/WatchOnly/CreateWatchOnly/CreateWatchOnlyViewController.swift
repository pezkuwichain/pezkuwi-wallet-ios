import UIKit
import Foundation_iOS
import UIKit_iOS

final class CreateWatchOnlyViewController: UIViewController, ViewHolder {
    typealias RootViewType = CreateWatchOnlyViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: CreateWatchOnlyPresenterProtocol

    var evmFieldEmpty: Bool { (rootView.evmAddressInputView.textField.text ?? "").isEmpty }

    var termsAccepted: Bool = false

    init(presenter: CreateWatchOnlyPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CreateWatchOnlyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard keyboardHandler == nil else { return }
        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }
}

// MARK: - Private

private extension CreateWatchOnlyViewController {
    func setupLocalization() {
        let localizedStrings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.titleLabel.text = localizedStrings.welcomeWatchOnlyTitle()
        rootView.detailsLabel.text = localizedStrings.createWatchOnlyDetails()

        rootView.presetSegmentControl.titles = [
            localizedStrings.welcomeWatchOnlyCustom(),
            localizedStrings.welcomeWatchOnlyDemo()
        ]

        rootView.walletNameTitleLabel.text = localizedStrings.walletUsernameSetupChooseTitle_v2_2_0()

        let placeholder = NSAttributedString(
            string: localizedStrings.watchOnlyWallet(),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.walletNameInputView.textField.attributedPlaceholder = placeholder

        rootView.substrateAddressTitleLabel.text = localizedStrings.watchOnlySubstrateAddressTitle()

        rootView.substrateAddressInputView.locale = selectedLocale

        rootView.evmAddressTitleLabel.text = localizedStrings.watchOnlyEvmAddressTitle()

        rootView.evmAddressInputView.locale = selectedLocale

        updateActionButtonState()
        setupTermsLocalization()
    }

    func setupTermsLocalization() {
        let localizedStrings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.termsControl.rowContentView.detailsLabel.attributedText = .coloredFontItems(
            [
                localizedStrings.watchOnlyTermsWarning()
            ],
            formattingClosure: { items in
                localizedStrings.watchOnlyTerms(items[0])
            },
            color: R.color.colorTextNegative()!,
            font: .regularSubheadline,
            defaultAttributes: [
                .font: UIFont.regularSubheadline,
                .foregroundColor: R.color.colorTextPrimary()!
            ]
        )
    }

    func setupHandlers() {
        rootView.genericActionView.addTarget(self, action: #selector(actionContinue), for: .touchUpInside)

        rootView.walletNameInputView.delegate = self

        rootView.walletNameInputView.addTarget(
            self,
            action: #selector(actionNicknameChanged),
            for: .editingChanged
        )

        rootView.substrateAddressInputView.delegate = self

        rootView.substrateAddressInputView.addTarget(
            self,
            action: #selector(actionSubstrateAddressChanged),
            for: .editingChanged
        )

        rootView.substrateAddressInputView.scanButton.addTarget(
            self,
            action: #selector(actionSubstrateAddressScan),
            for: .touchUpInside
        )

        rootView.evmAddressInputView.delegate = self

        rootView.evmAddressInputView.addTarget(
            self,
            action: #selector(actionEVMAddressChanged),
            for: .editingChanged
        )

        rootView.evmAddressInputView.scanButton.addTarget(
            self,
            action: #selector(actionEVMAddressScan),
            for: .touchUpInside
        )

        rootView.presetSegmentControl.addTarget(
            self,
            action: #selector(actionPreset),
            for: .valueChanged
        )

        rootView.termsControl.addTarget(
            self,
            action: #selector(actionTermsTap),
            for: .touchUpInside
        )
    }

    func updateActionButtonState() {
        guard rootView.walletNameInputView.completed else {
            setDisabledButton { $0.createWatchOnlyMissingWalletName() }
            return
        }
        guard rootView.substrateAddressInputView.completed || rootView.evmAddressInputView.completed else {
            setDisabledButton { $0.createWatchOnlyMissingAnyAddress() }
            return
        }
        guard termsAccepted else {
            setDisabledButton { $0.watchOnlyAcceptTermsButtonTitle() }
            return
        }

        rootView.genericActionView.applyEnabledStyle()
        rootView.genericActionView.isUserInteractionEnabled = true

        rootView.genericActionView.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()
        rootView.genericActionView.invalidateLayout()
    }

    func setDisabledButton(titleClosure: (_R.string.localizable) -> String) {
        rootView.genericActionView.applyDisabledStyle()
        rootView.genericActionView.isUserInteractionEnabled = false

        rootView.genericActionView.imageWithTitleView?.title = titleClosure(
            R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        )

        rootView.genericActionView.invalidateLayout()
    }

    func updateReturnButton(for selectedInputView: UIView) {
        if selectedInputView === rootView.walletNameInputView {
            if rootView.substrateAddressInputView.completed, !evmFieldEmpty {
                rootView.walletNameInputView.textField.returnKeyType = .done
            } else {
                rootView.walletNameInputView.textField.returnKeyType = .next
            }
        }

        if selectedInputView === rootView.substrateAddressInputView {
            if !evmFieldEmpty {
                rootView.substrateAddressInputView.textField.returnKeyType = .done
            } else {
                rootView.substrateAddressInputView.textField.returnKeyType = .next
            }
        }
    }

    func completeInputOn(field: UIView) {
        if field === rootView.walletNameInputView {
            rootView.walletNameInputView.textField.resignFirstResponder()

            if !rootView.substrateAddressInputView.completed {
                rootView.substrateAddressInputView.textField.becomeFirstResponder()
            } else if evmFieldEmpty {
                rootView.evmAddressInputView.textField.becomeFirstResponder()
            }
        }

        if field === rootView.substrateAddressInputView {
            rootView.substrateAddressInputView.textField.resignFirstResponder()

            if evmFieldEmpty {
                rootView.evmAddressInputView.textField.becomeFirstResponder()
            }
        }

        if field === rootView.evmAddressInputView {
            rootView.evmAddressInputView.textField.resignFirstResponder()
        }
    }

    // MARK: - Actions

    @objc func actionNicknameChanged() {
        let partialNickName = rootView.walletNameInputView.textField.text ?? ""
        presenter.updateWalletNickname(partialNickName)

        updateActionButtonState()
    }

    @objc func actionSubstrateAddressChanged() {
        let partialAddress = rootView.substrateAddressInputView.textField.text ?? ""
        presenter.updateSubstrateAddress(partialAddress)

        updateActionButtonState()
    }

    @objc func actionSubstrateAddressScan() {
        presenter.performSubstrateScan()
    }

    @objc func actionEVMAddressChanged() {
        let partialAddress = rootView.evmAddressInputView.textField.text ?? ""
        presenter.updateEVMAddress(partialAddress)

        updateActionButtonState()
    }

    @objc func actionEVMAddressScan() {
        presenter.performEVMScan()
    }

    @objc func actionContinue() {
        presenter.performContinue()
    }

    @objc func actionPreset(_: RoundedButton) {
        let index = rootView.presetSegmentControl.selectedSegmentIndex

        presenter.selectMode(for: index)
    }

    @objc func actionTermsTap() {
        presenter.toggleTermsCheckbox()
    }
}

// MARK: - TextInputViewDelegate

extension CreateWatchOnlyViewController: TextInputViewDelegate {
    func textInputViewShouldReturn(_ inputView: TextInputView) -> Bool {
        completeInputOn(field: inputView)
        return true
    }

    func textInputViewWillStartEditing(_ inputView: TextInputView) {
        updateReturnButton(for: inputView)
    }
}

// MARK: - AccountInputViewDelegate

extension CreateWatchOnlyViewController: AccountInputViewDelegate {
    func accountInputViewDidEndEditing(_: AccountInputView) {}

    func accountInputViewShouldReturn(_ inputView: AccountInputView) -> Bool {
        completeInputOn(field: inputView)
        return true
    }

    func accountInputViewWillStartEditing(_ inputView: AccountInputView) {
        updateReturnButton(for: inputView)
    }

    func accountInputViewDidPaste(_: AccountInputView) {}
}

// MARK: - CreateWatchOnlyViewProtocol

extension CreateWatchOnlyViewController: CreateWatchOnlyViewProtocol {
    func didReceiveNickname(viewModel: InputViewModelProtocol) {
        rootView.walletNameInputView.bind(inputViewModel: viewModel)

        if viewModel.inputHandler.enabled {
            rootView.walletNameInputView.applyDefaultState()
        } else {
            rootView.walletNameInputView.applyLockedState()
        }

        updateActionButtonState()
    }

    func didReceiveSubstrateAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.substrateAddressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveSubstrateAddressInput(viewModel: InputViewModelProtocol) {
        rootView.substrateAddressInputView.bind(inputViewModel: viewModel)

        if viewModel.inputHandler.enabled {
            rootView.substrateAddressInputView.applyDefaultState()
        } else {
            rootView.substrateAddressInputView.applyLockedState()
        }

        updateActionButtonState()
    }

    func didReceiveEVMAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.evmAddressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveEVMAddressInput(viewModel: InputViewModelProtocol) {
        rootView.evmAddressInputView.bind(inputViewModel: viewModel)

        if viewModel.inputHandler.enabled {
            rootView.evmAddressInputView.applyDefaultState()
        } else {
            rootView.evmAddressInputView.applyLockedState()
        }

        updateActionButtonState()
    }

    func didReceiveTerms(accepted: Bool) {
        guard termsAccepted != accepted else { return }

        termsAccepted = accepted

        rootView.termsControl.rowContentView.imageView.image = accepted
            ? R.image.iconCheckbox()
            : R.image.iconCheckboxEmpty()

        updateActionButtonState()
    }
}

// MARK: - Localizable

extension CreateWatchOnlyViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }
        setupLocalization()
    }
}
