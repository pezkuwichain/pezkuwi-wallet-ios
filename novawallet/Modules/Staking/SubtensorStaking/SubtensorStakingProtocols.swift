import Foundation
import UIKit
import BigInt

protocol SubtensorStakingViewProtocol: AnyObject {
    var controller: UIViewController { get }

    func didReceive(validators: [SubtensorValidator])
    func didReceive(positions: [SubtensorStakePosition])
    func didReceive(minDelegation: BigUInt)
    func didReceiveStatus(_ status: String)
}

protocol SubtensorStakingInteractorInputProtocol: AnyObject {
    func setup()
    func refreshValidators()
    func submitStake(hotkey: AccountId, amount: BigUInt)
}

protocol SubtensorStakingInteractorOutputProtocol: AnyObject {
    func didReceive(validators: [SubtensorValidator])
    func didReceive(stakePositions: [SubtensorStakePosition])
    func didReceive(minDelegation: BigUInt)
    func didReceive(error: Error)
}

protocol SubtensorStakingPresenterProtocol: AnyObject {
    func setup()
    func didTapStake()
}

protocol SubtensorStakingWireframeProtocol: AnyObject {
    func showError(from view: UIViewController, message: String)
}
