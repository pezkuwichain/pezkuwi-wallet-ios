import Foundation
import BigInt
import UIKit

final class SubtensorStakingPresenter: SubtensorStakingPresenterProtocol {
    weak var view: SubtensorStakingViewProtocol?
    let interactor: SubtensorStakingInteractorInputProtocol
    let wireframe: SubtensorStakingWireframeProtocol

    private var validators: [SubtensorValidator] = []
    private var positions: [SubtensorStakePosition] = []
    private var minDelegation: BigUInt?

    init(
        interactor: SubtensorStakingInteractorInputProtocol,
        wireframe: SubtensorStakingWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func setup() {
        interactor.setup()
    }

    func didTapStake() {
        // v1 stub flow: pick the first validator in the list and submit a
        // minimal stake. Real flow has a picker + amount input — that comes
        // once the UI shell is QA'd.
        guard let first = validators.first, let min = minDelegation else {
            view?.didReceiveStatus("No validators loaded yet")
            return
        }
        interactor.submitStake(hotkey: first.hotkey, amount: min)
    }
}

extension SubtensorStakingPresenter: SubtensorStakingInteractorOutputProtocol {
    func didReceive(validators: [SubtensorValidator]) {
        self.validators = validators
        view?.didReceive(validators: validators)
    }

    func didReceive(stakePositions: [SubtensorStakePosition]) {
        positions = stakePositions
        view?.didReceive(positions: stakePositions)
    }

    func didReceive(minDelegation: BigUInt) {
        self.minDelegation = minDelegation
        view?.didReceive(minDelegation: minDelegation)
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorStaking: service error — \(error.localizedDescription)")
        guard let view else { return }
        wireframe.showError(from: view.controller, message: error.localizedDescription)
        view.didReceiveStatus("Unable to load validators")
    }
}
