import Foundation
import Foundation_iOS

extension InputViewModel {
    static func createNicknameInputViewModel(
        for value: String,
        required: Bool = true,
        enabled: Bool = true
    ) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            enabled: enabled,
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        return InputViewModel(inputHandler: inputHandling)
    }
}
