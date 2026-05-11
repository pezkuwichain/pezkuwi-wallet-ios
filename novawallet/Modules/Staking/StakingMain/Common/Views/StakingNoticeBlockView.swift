import UIKit

/// Expanded notice block shown at the top of the stake-details screen.
/// Shows severity-coloured background, a dot + bold title row, and the full longText body.
final class StakingNoticeBlockView: UIView {
    struct Model: Equatable {
        enum Severity: Equatable { case info; case critical }
        let severity: Severity
        let title: String
        let body: String
    }

    private let containerView = UIView()
    private let headDot = UIView()
    private let headLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: Model?) {
        guard let model else {
            isHidden = true
            return
        }
        isHidden = false

        let (background, border, foreground): (UIColor, UIColor, UIColor) = model.severity == .critical
            ? (
                R.color.colorErrorBlockBackground()!,
                R.color.colorTextNegative()!.withAlphaComponent(0.30),
                R.color.colorTextNegative()!
            )
            : (
                R.color.colorWarningBlockBackground()!,
                R.color.colorTextWarning()!.withAlphaComponent(0.25),
                R.color.colorTextWarning()!
            )

        containerView.backgroundColor = background
        containerView.layer.borderColor = border.cgColor
        headDot.backgroundColor = foreground
        headLabel.textColor = foreground
        headLabel.text = model.title
        bodyLabel.text = model.body
    }

    private func configure() {
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1

        [headDot, headLabel, bodyLabel].forEach {
            containerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        headDot.layer.cornerRadius = 3
        headLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bodyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = R.color.colorTextSecondary()!

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            headDot.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            headDot.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headDot.widthAnchor.constraint(equalToConstant: 6),
            headDot.heightAnchor.constraint(equalToConstant: 6),

            headLabel.leadingAnchor.constraint(equalTo: headDot.trailingAnchor, constant: 8),
            headLabel.centerYAnchor.constraint(equalTo: headDot.centerYAnchor),
            headLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),

            bodyLabel.topAnchor.constraint(equalTo: headLabel.bottomAnchor, constant: 6),
            bodyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            bodyLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14)
        ])
    }
}
