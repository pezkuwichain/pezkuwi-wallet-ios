import UIKit
import SubstrateSdk

/// Two-line table cell for the Subtensor validator picker.
///
/// Layout:
///   left column   : identicon (32pt) + name/hotkey (line 1) + short hotkey (line 2)
///   right column  : commission (line 1, value) + commission caption (small)
///                   total stake (line 1, value) + stake caption (small)
///
/// The cell mirrors `CollatorSelectionCell`'s density / spacing without
/// pulling in fields v1 doesn't have (sort-by metric, info button, warning
/// state, APR). Subnet variants can render `subnetBadge` as a small chip
/// trailing the name; v1 keeps that hidden.
final class SubtensorValidatorTableViewCell: UITableViewCell {
    static let reuseId = "SubtensorValidatorTableViewCell"

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

    let commissionLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .right
        return label
    }()

    let commissionCaptionLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .right
        // TODO(phase-e): R.string.localizable.stakingSubtensorCommissionCaption(...)
        label.text = "commission"
        return label
    }()

    let totalStakeLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .right
        return label
    }()

    let stakeCaptionLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .right
        // TODO(phase-e): R.string.localizable.stakingSubtensorTotalStakeCaption(...)
        label.text = "total stake"
        return label
    }()

    let subnetBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .caption2
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.layer.borderWidth = 0.5
        label.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        label.isHidden = true
        return label
    }()

    private let leftStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }()

    private let nameRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()

    private let commissionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 0
        return stack
    }()

    private let stakeStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 0
        return stack
    }()

    private let rightStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16
        stack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear
        selectionStyle = .default

        let bgView = UIView()
        bgView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = bgView

        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }

    private func setupLayout() {
        // Identicon: 32pt
        contentView.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32)
        ])

        // Right side stacks
        commissionStack.addArrangedSubview(commissionLabel)
        commissionStack.addArrangedSubview(commissionCaptionLabel)
        stakeStack.addArrangedSubview(totalStakeLabel)
        stakeStack.addArrangedSubview(stakeCaptionLabel)

        rightStack.addArrangedSubview(commissionStack)
        rightStack.addArrangedSubview(stakeStack)

        contentView.addSubview(rightStack)
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rightStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rightStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            rightStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])

        // Left side: name row + hotkey
        nameRowStack.addArrangedSubview(nameLabel)
        nameRowStack.addArrangedSubview(subnetBadgeLabel)
        leftStack.addArrangedSubview(nameRowStack)
        leftStack.addArrangedSubview(hotkeyLabel)

        contentView.addSubview(leftStack)
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            leftStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -12),
            leftStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            leftStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func bind(viewModel: SubtensorValidatorCellViewModel) {
        if let icon = viewModel.identicon {
            iconView.bind(icon: icon)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }

        if let name = viewModel.displayName, !name.isEmpty {
            nameLabel.text = name
            nameLabel.font = .semiBoldFootnote
            hotkeyLabel.isHidden = false
            hotkeyLabel.text = viewModel.shortHotkey
        } else {
            // No identity — promote the hotkey into the title slot in monospace
            // and hide the secondary line.
            nameLabel.text = viewModel.shortHotkey
            nameLabel.font = .systemFont(ofSize: 13, weight: .regular).monospaced()
            hotkeyLabel.isHidden = true
        }

        commissionLabel.text = viewModel.commissionText
        totalStakeLabel.text = viewModel.totalStakeText

        if let badge = viewModel.subnetBadge, !badge.isEmpty {
            subnetBadgeLabel.text = "  \(badge)  "
            subnetBadgeLabel.isHidden = false
        } else {
            subnetBadgeLabel.text = nil
            subnetBadgeLabel.isHidden = true
        }

        setNeedsLayout()
    }
}

// MARK: - Helpers

private extension UIFont {
    func monospaced() -> UIFont {
        let descriptor = fontDescriptor.withDesign(.monospaced) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
