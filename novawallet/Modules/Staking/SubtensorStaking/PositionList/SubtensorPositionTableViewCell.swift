import UIKit
import SubstrateSdk

/// Table cell for a single user stake position on the TAO staking dashboard.
///
/// Layout:
///   left column  : identicon (32pt) | name/hotkey | network badge
///   right column : formatted amount
final class SubtensorPositionTableViewCell: UITableViewCell {
    static let reuseId = "SubtensorPositionTableViewCell"

    // MARK: Subviews

    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldFootnote
        label.textColor = R.color.colorTextPrimary()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let hotkeyLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    let networkBadge: UILabel = {
        let label = UILabel()
        label.font = .caption2
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.layer.borderWidth = 0.5
        label.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        return label
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .right
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    // MARK: Private layout stacks

    private let networkRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()

    private let leftStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }()

    // MARK: Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupAppearance()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    // MARK: Layout

    private func setupAppearance() {
        backgroundColor = .clear
        selectionStyle = .default
        let bg = UIView()
        bg.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = bg
        separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)
    }

    private func setupLayout() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32)
        ])

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(amountLabel)
        NSLayoutConstraint.activate([
            amountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            amountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        networkRow.addArrangedSubview(nameLabel)
        networkRow.addArrangedSubview(networkBadge)
        leftStack.addArrangedSubview(networkRow)
        leftStack.addArrangedSubview(hotkeyLabel)

        leftStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(leftStack)
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            leftStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),
            leftStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            leftStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    // MARK: Binding

    func bind(viewModel: SubtensorPositionViewModel) {
        if let icon = viewModel.identicon {
            iconView.bind(icon: icon)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }

        nameLabel.text = viewModel.nameText
        if viewModel.nameIsAddress {
            nameLabel.font = .systemFont(ofSize: 13, weight: .regular).monospaced()
            hotkeyLabel.isHidden = true
        } else {
            nameLabel.font = .semiBoldFootnote
            hotkeyLabel.text = viewModel.shortHotkey
            hotkeyLabel.isHidden = viewModel.shortHotkey == nil
        }

        networkBadge.text = "  \(viewModel.networkText)  "
        amountLabel.text = viewModel.amountText

        setNeedsLayout()
    }
}

private extension UIFont {
    func monospaced() -> UIFont {
        let descriptor = fontDescriptor.withDesign(.monospaced) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
