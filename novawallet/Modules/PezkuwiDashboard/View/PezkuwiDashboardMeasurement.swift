import UIKit

/// Fixed-height constants for the Pezkuwi dashboard card, following the same "all cell heights are
/// hard-coded constants" convention already used by `AssetListMeasurement` (this custom
/// `UICollectionViewFlowLayout` computes cell sizes manually rather than via self-sizing cells).
enum PezkuwiDashboardMeasurement {
    /// Slim single-line collapsed pill — matches the Android spec: "~44pt tall".
    static let collapsedHeight: CGFloat = 44.0

    /// Approximate height of the expanded card content (header row + role chips wrapping up to
    /// ~2 lines + trust-score row + 3 stacked action buttons + paddings). Unlike Android's
    /// `wrap_content` `LinearLayout`, this collection view's custom flow layout requires an
    /// upfront fixed height rather than self-sizing — this constant is a best-effort estimate and
    /// is the most likely value to need on-device tuning.
    static let expandedHeight: CGFloat = 328.0

    static let cardInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)

    static let cardCornerRadius: CGFloat = 20.0
    static let collapsedCornerRadius: CGFloat = 22.0

    static let buttonHeight: CGFloat = 48.0
    static let trackingButtonHeight: CGFloat = 32.0
    static let contentPadding: CGFloat = 18.0
}
