import UIKit

final class TimerButton: UIControl {
    private let titleLabel: UILabel = .create { view in
        view.font = .semiBoldSubheadline
        view.textAlignment = .center
    }

    private let backgroundLayer = CALayer()
    private let progressLayer = CALayer()

    private var totalDuration: TimeInterval = 0
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0

    var isTimerActive: Bool = true {
        didSet {
            updateAppearance()
        }
    }

    var activeColor: UIColor = R.color.colorButtonBackgroundPrimary()!

    override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopAnimation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - Private

private extension TimerButton {
    func setupView() {
        layer.cornerRadius = 12
        layer.masksToBounds = true

        backgroundLayer.backgroundColor = R.color.colorButtonBackgroundInactive()?.cgColor
        layer.addSublayer(backgroundLayer)

        progressLayer.backgroundColor = R.color.colorBlockBackground()?.cgColor
        progressLayer.frame = CGRect(x: 0, y: 0, width: 0, height: bounds.height)
        layer.addSublayer(progressLayer)

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        isEnabled = false
        updateAppearance()
    }

    func updateAppearance() {
        if isTimerActive {
            titleLabel.textColor = R.color.colorTextSecondary()
            backgroundLayer.backgroundColor = R.color.colorButtonBackgroundInactive()?.cgColor
            progressLayer.isHidden = false
        } else {
            titleLabel.textColor = .white
            backgroundLayer.backgroundColor = activeColor.cgColor
            progressLayer.isHidden = true
        }
    }

    func startAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgress))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc func updateProgress() {
        guard totalDuration > 0 else { return }

        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = min(elapsed / totalDuration, 1.0)
        let progressWidth = bounds.width * progress

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: progressWidth,
            height: bounds.height
        )
        CATransaction.commit()
    }
}

// MARK: - Internal

extension TimerButton {
    func startTimer(totalSeconds: Int) {
        totalDuration = TimeInterval(totalSeconds)
        animationStartTime = CACurrentMediaTime()

        updateTimerLabel(remainingSeconds: totalSeconds)
        startAnimation()
    }

    func updateTimerLabel(remainingSeconds: Int) {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        titleLabel.text = String(format: "%d:%02d", minutes, seconds)
    }

    func finishTimer(title: String) {
        stopAnimation()
        isTimerActive = false
        isEnabled = true
        titleLabel.text = title

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.frame = bounds
        CATransaction.commit()
    }
}
