import UIKit
import Foundation_iOS

final class InfoPopupViewController: UIViewController, ViewHolder {
    typealias RootViewType = InfoPopupViewLayout

    let presenter: InfoPopupPresenterProtocol
    let bannersViewProvider: BannersViewProviderProtocol?

    private var learnMoreTitle: String?

    init(
        presenter: InfoPopupPresenterProtocol,
        bannersViewProvider: BannersViewProviderProtocol?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.bannersViewProvider = bannersViewProvider
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = InfoPopupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBanner()
        setupHandlers()
        presenter.setup()
    }
}

// MARK: - Private

private extension InfoPopupViewController {
    func setupNavigation() {
        guard let learnMoreTitle else {
            navigationController?.navigationBar.topItem?.rightBarButtonItem = nil
            return
        }

        let barButtonItem = UIBarButtonItem(
            title: learnMoreTitle,
            style: .plain,
            target: self,
            action: #selector(actionLearnMore)
        )
        barButtonItem.tintColor = R.color.colorButtonTextAccent()

        navigationController?.navigationBar.topItem?.rightBarButtonItem = barButtonItem
    }

    func setupBanner() {
        guard let bannersViewProvider else {
            rootView.bannerContainer.isHidden = true
            return
        }

        bannersViewProvider.setupBanners(
            on: self,
            view: rootView.bannerContainer
        )
        updateBannerHeight()
    }

    func setupHandlers() {
        rootView.mainActionButton.addTarget(
            self,
            action: #selector(actionMain),
            for: .touchUpInside
        )

        rootView.skipButton.addTarget(
            self,
            action: #selector(actionSkip),
            for: .touchUpInside
        )
    }

    func updateBannerHeight() {
        let bannerHeight = bannersViewProvider?.getMaxBannerHeight() ?? 0
        rootView.updateBannerHeight(bannerHeight)
    }

    @objc func actionMain() {
        presenter.actionMain()
    }

    @objc func actionSkip() {
        presenter.actionSkip()
    }

    @objc func actionLearnMore() {
        presenter.actionLearnMore()
    }
}

// MARK: - InfoPopupViewProtocol

extension InfoPopupViewController: InfoPopupViewProtocol {
    func didReceive(viewModel: InfoPopupViewModel) {
        rootView.bind(viewModel)
        updateBannerHeight()

        learnMoreTitle = viewModel.learnMoreTitle
        setupNavigation()
    }
}

// MARK: - Localizable

extension InfoPopupViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupNavigation()
    }
}
