import Foundation
import UIKit
import BigInt

protocol SubtensorStakingViewProtocol: AnyObject {
    var controller: UIViewController { get }

    func didReceive(positions: [SubtensorPositionViewModel])
    func didReceiveStatus(_ status: String)
}

protocol SubtensorStakingInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol SubtensorStakingInteractorOutputProtocol: AnyObject {
    func didReceive(positions: [SubtensorStakePosition])
    func didReceive(minDelegation: BigUInt)
    func didReceive(error: Error)
}

protocol SubtensorStakingPresenterProtocol: AnyObject {
    func setup()
    func didTapStake()
}

protocol SubtensorStakingWireframeProtocol: AnyObject {
    func showStakingFlow(from view: UIViewController)
    func showError(from view: UIViewController, message: String)
}
