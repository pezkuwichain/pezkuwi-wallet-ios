import Foundation
import BigInt
import UIKit

final class SubtensorStakingPresenter: SubtensorStakingPresenterProtocol {
    weak var view: SubtensorStakingViewProtocol?
    let interactor: SubtensorStakingInteractorInputProtocol
    let wireframe: SubtensorStakingWireframeProtocol

    private let chainAsset: ChainAsset
    private var positions: [SubtensorStakePosition] = []
    private var minDelegation: BigUInt?

    init(
        interactor: SubtensorStakingInteractorInputProtocol,
        wireframe: SubtensorStakingWireframeProtocol,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
    }

    func setup() {
        view?.didReceiveStatus("loading")
        interactor.setup()
    }

    func didTapStake() {
        guard let controller = view?.controller else { return }
        wireframe.showStakingFlow(from: controller)
    }
}

extension SubtensorStakingPresenter: SubtensorStakingInteractorOutputProtocol {
    func didReceive(positions: [SubtensorStakePosition]) {
        self.positions = positions

        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let viewModels = positions.map {
            SubtensorPositionViewModel.make(from: $0, assetPrecision: precision)
        }

        view?.didReceive(positions: viewModels)
    }

    func didReceive(minDelegation: BigUInt) {
        self.minDelegation = minDelegation
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorStaking: \(error.localizedDescription)")
        guard let view else { return }
        wireframe.showError(from: view.controller, message: error.localizedDescription)
        view.didReceiveStatus("error")
    }
}
