import UIKit

final class NoticeStripView: UIView {
    private let dot = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(to banner: StakingNoticeBanner?) {
        guard let banner else {
            isHidden = true
            return
        }
        isHidden = false
        let (background, foreground) = banner.severity == .critical
            ? (R.color.colorErrorBlockBackground()!, R.color.colorTextNegative()!)
            : (R.color.colorWarningBlockBackground()!, R.color.colorTextWarning()!)
        backgroundColor = background
        dot.backgroundColor = foreground
        label.textColor = foreground
        label.text = banner.text
    }

    private func configure() {
        addSubview(dot)
        addSubview(label)
        dot.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 3
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 1
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }
}
