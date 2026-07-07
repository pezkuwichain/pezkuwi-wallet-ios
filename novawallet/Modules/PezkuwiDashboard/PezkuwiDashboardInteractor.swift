import Foundation
import Operation_iOS
import SubstrateSdk

final class PezkuwiDashboardInteractor {
    weak var presenter: PezkuwiDashboardInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let chainRegistry: ChainRegistryProtocol
    let repository: PezkuwiDashboardRepositoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let fetchCallStore = CancellableCallStore()

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        repository: PezkuwiDashboardRepositoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension PezkuwiDashboardInteractor {
    /// Resolves the currently selected wallet's account id on the Pezkuwi People chain,
    /// mirroring Android's `PezkuwiDashboardInteractor.getDashboard`: if no chain or no account
    /// exists yet, the whole card stays hidden rather than showing degraded/default data.
    func resolveAccountId() -> AccountId? {
        guard let wallet = selectedWalletSettings.value else { return nil }
        guard let chain = chainRegistry.getChain(for: KnowChainId.pezkuwiPeople) else { return nil }

        return wallet.fetchChainAccountId(for: chain.accountRequest())
    }

    func fetchDashboard() {
        fetchCallStore.cancel()

        guard let accountId = resolveAccountId() else {
            presenter?.didReceive(dashboard: nil)
            return
        }

        let wrapper = repository.fetchDashboardWrapper(for: accountId)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: fetchCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(dashboard):
                self?.presenter?.didReceive(dashboard: dashboard)
            case let .failure(error):
                self?.logger.error("Pezkuwi dashboard fetch failed: \(error)")
                self?.presenter?.didReceive(dashboard: nil)
            }
        }
    }

    func submitStartTracking(accountId: AccountId) {
        do {
            let chain = try chainRegistry.getChainOrError(for: KnowChainId.pezkuwiPeople)
            let connection = try chainRegistry.getConnectionOrError(for: KnowChainId.pezkuwiPeople)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: KnowChainId.pezkuwiPeople)

            guard
                let wallet = selectedWalletSettings.value,
                let accountResponse = wallet.fetchMetaChainAccount(for: chain.accountRequest())
            else {
                presenter?.didReceiveTracking(error: ChainAccountFetchingError.accountNotExists)
                return
            }

            let extrinsicServiceFactory = ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: UserDataStorageFacade.shared,
                substrateStorageFacade: SubstrateDataStorageFacade.shared
            )

            let extrinsicService = extrinsicServiceFactory.createService(
                account: accountResponse.chainAccount,
                chain: chain
            )

            let signingWrapper = SigningWrapperFactory().createSigningWrapper(
                for: wallet.metaId,
                accountResponse: accountResponse.chainAccount
            )

            extrinsicService.submit(
                { builder in
                    try builder.adding(
                        call: RuntimeCall(moduleName: "StakingScore", callName: "start_score_tracking")
                    )
                },
                payingIn: nil,
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.presenter?.didStartTracking()
                    self?.fetchDashboard()
                case let .failure(error):
                    self?.presenter?.didReceiveTracking(error: error)
                }
            }
        } catch {
            presenter?.didReceiveTracking(error: error)
        }
    }
}

// MARK: - PezkuwiDashboardInteractorInputProtocol

extension PezkuwiDashboardInteractor: PezkuwiDashboardInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        fetchDashboard()
    }

    func refresh() {
        fetchDashboard()
    }

    func startTracking() {
        guard let accountId = resolveAccountId() else {
            presenter?.didReceiveTracking(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        submitStartTracking(accountId: accountId)
    }

    func requestReferralAddress() {
        do {
            let chain = try chainRegistry.getChainOrError(for: KnowChainId.pezkuwiPeople)

            guard let accountId = resolveAccountId() else {
                return
            }

            let address = try accountId.toAddress(using: chain.chainFormat)

            presenter?.didReceive(referralAddress: address)
        } catch {
            logger.error("Pezkuwi dashboard referral address failed: \(error)")
        }
    }
}

// MARK: - EventVisitorProtocol

extension PezkuwiDashboardInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        fetchDashboard()
    }
}
