import Foundation

struct AssetListFullUpdateViewModel {
    let inlinableAlert: InlinableAlertView.Model?
    let header: AssetListHeaderViewModel
    let assetGroups: AssetListViewModel
    let organizer: AssetListOrganizerViewModel?
}
