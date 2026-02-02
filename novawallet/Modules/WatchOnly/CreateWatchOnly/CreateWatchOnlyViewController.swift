import UIKit
import Foundation_iOS
import UIKit_iOS

final class CreateWatchOnlyViewController: UIViewController, ViewHolder {
    typealias RootViewType = CreateWatchOnlyViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: CreateWatchOnlyPresenterProtocol

    var evmFieldEmpty: Bool { (rootView.evmAddressInputView.textField.text ?? "").isEmpty }

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

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
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

        rootView.termsView.rowContentView.detailsLabel.attributedText = .coloredFontItems(
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
    }

    func updateActionButtonState() {
        if !rootView.walletNameInputView.completed {
            rootView.genericActionView.applyDisabledStyle()
            rootView.genericActionView.isUserInteractionEnabled = false

            rootView.genericActionView.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable
                .createWatchOnlyMissingNickname()
            rootView.genericActionView.invalidateLayout()

            return
        }

        if !rootView.substrateAddressInputView.completed {
            rootView.genericActionView.applyDisabledStyle()
            rootView.genericActionView.isUserInteractionEnabled = false

            rootView.genericActionView.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable
                .createWatchOnlyMissingSubstrate()
            rootView.genericActionView.invalidateLayout()

            return
        }

        rootView.genericActionView.applyEnabledStyle()
        rootView.genericActionView.isUserInteractionEnabled = true

        rootView.genericActionView.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()
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
}

// MARK: - KeyboardAdoptable

extension CreateWatchOnlyViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if rootView.walletNameInputView.textField.isFirstResponder {
                targetView = rootView.walletNameInputView
            } else if rootView.substrateAddressInputView.textField.isFirstResponder {
                targetView = rootView.substrateAddressInputView
            } else if rootView.evmAddressInputView.textField.isFirstResponder {
                targetView = rootView.evmAddressInputView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
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

        updateActionButtonState()
    }

    func didReceiveSubstrateAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.substrateAddressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveSubstrateAddressInput(viewModel: InputViewModelProtocol) {
        rootView.substrateAddressInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveEVMAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.evmAddressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveEVMAddressInput(viewModel: InputViewModelProtocol) {
        rootView.evmAddressInputView.bind(inputViewModel: viewModel)

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
