import Foundation
import BigInt

final class SubtensorStakingInteractor: SubtensorStakingInteractorInputProtocol {
    weak var presenter: SubtensorStakingInteractorOutputProtocol?

    private let service: SubtensorStakingService
    private var setupTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(service: SubtensorStakingService) {
        self.service = service
    }

    deinit {
        setupTask?.cancel()
        refreshTask?.cancel()
    }

    func setup() {
        // Cancel-and-replace: re-entering setup (e.g. pull-to-refresh) cancels the
        // prior task so its callbacks don't clobber fresher state.
        setupTask?.cancel()
        setupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // TODO(integration): the async-let fan-out only parallelizes once the
                // service methods actually suspend. Today only `fetchActiveValidators`
                // suspends (at BittensorDelegatesClient.fetchDelegates); `fetchUserStakePositions`
                // and `fetchMinDelegation` are sync stubs. Verify true parallelism once
                // real storage queries are wired.
                async let validators = service.fetchActiveValidators(
                    netuid: SubtensorStakingConstants.rootNetuid
                )
                async let positions = service.fetchUserStakePositions(
                    netuid: SubtensorStakingConstants.rootNetuid
                )
                async let minDelegation = service.fetchMinDelegation()

                let (fetchedValidators, fetchedPositions, fetchedMinDelegation) = try await(
                    validators, positions, minDelegation
                )
                guard !Task.isCancelled else { return }
                presenter?.didReceive(validators: fetchedValidators)
                presenter?.didReceive(stakePositions: fetchedPositions)
                presenter?.didReceive(minDelegation: fetchedMinDelegation)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }

    func refreshValidators() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let validators = try await service.fetchActiveValidators(
                    netuid: SubtensorStakingConstants.rootNetuid
                )
                guard !Task.isCancelled else { return }
                presenter?.didReceive(validators: validators)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }

    func submitStake(hotkey: AccountId, amount: BigUInt) {
        // v1 stub: construct the call via SubtensorExtrinsicBuilder but do
        // NOT actually submit. Real ExtrinsicService wiring is deferred to
        // the integration pass. The builder call here exists to verify the
        // codepath wires together at compile time.
        _ = SubtensorExtrinsicBuilder.buildAddStakeLimit(
            hotkey: hotkey,
            netuid: SubtensorStakingConstants.rootNetuid,
            amount: amount,
            slippage: SubtensorStakingConstants.defaultSlippage
        )
        // TODO(integration): inject ExtrinsicServiceProtocol, call its submit
        // method with the built call and a signer, subscribe to finalization
        // events, route results back to the presenter via didReceiveError
        // or a new didReceiveSubmissionResult callback.
    }
}
