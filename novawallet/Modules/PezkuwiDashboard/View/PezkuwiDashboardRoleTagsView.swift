import UIKit
import UIKit_iOS

/// Minimal horizontally-wrapping "chip row" container — this codebase has no existing
/// flow/wrap container view (confirmed by search: only a single-chip `BorderedLabelView` exists,
/// no multi-chip flow layout), so this is a small purpose-built one, laying out `BorderedLabelView`
/// chips left-to-right and wrapping to a new row once the current row runs out of width.
final class PezkuwiDashboardRoleTagsView: UIView {
    private(set) var chipViews: [BorderedLabelView] = []

    var horizontalSpacing: CGFloat = 6.0
    var verticalSpacing: CGFloat = 4.0

    func bind(roles: [String]) {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews = []

        for role in roles {
            let chip = BorderedLabelView()
            chip.titleLabel.text = role
            chip.titleLabel.textColor = R.color.colorTextPrimary()
            chip.backgroundView.fillColor = R.color.colorChipsBackground()!

            addSubview(chip)
            chipViews.append(chip)
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutChips(width: bounds.width)
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIView.layoutFittingCompressedSize.width
        let height = layoutChips(width: width, apply: false)

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    @discardableResult
    private func layoutChips(width: CGFloat, apply: Bool = true) -> CGFloat {
        guard width > 0, !chipViews.isEmpty else { return 0 }

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for chip in chipViews {
            let size = chip.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))

            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            if apply {
                chip.frame = CGRect(x: currentX, y: currentY, width: size.width, height: size.height)
            }

            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        return currentY + rowHeight
    }
}
