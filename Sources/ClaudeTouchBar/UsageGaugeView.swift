import AppKit
import QuartzCore

final class UsageGaugeView: NSView {
    private let title: String
    private var percent: Double?
    private var detail: String = ""

    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "--%")
    private let detailLabel = NSTextField(labelWithString: "")
    private let track = CALayer()
    private let fill = CALayer()

    private let barWidth: CGFloat = 120

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        wantsLayer = true

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = Theme.text
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        percentLabel.textColor = Theme.text
        percentLabel.alignment = .right
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = Theme.secondaryText

        for v in [titleLabel, percentLabel, detailLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        track.backgroundColor = Theme.track.cgColor
        track.cornerRadius = 4
        fill.backgroundColor = Theme.claude.cgColor
        fill.cornerRadius = 4
        layer?.addSublayer(track)
        track.addSublayer(fill)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 58),

            percentLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: barWidth + 14),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentLabel.widthAnchor.constraint(equalToConstant: 40),

            detailLabel.leadingAnchor.constraint(equalTo: percentLabel.trailingAnchor, constant: 8),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: 58 + barWidth + 40 + 125 + 34, height: 30) }

    override func layout() {
        super.layout()
        layoutTrack()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutTrack()
    }

    private func layoutTrack() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = CGRect(x: 6 + 58 + 7, y: bounds.midY - 4, width: barWidth, height: 8)
        CATransaction.commit()
        layoutFill(animated: false)
    }

    func update(percent: Double?, detail: String) {
        self.percent = percent
        self.detail = detail
        percentLabel.stringValue = Format.percent(percent)
        detailLabel.stringValue = detail
        fill.backgroundColor = Theme.color(forPercent: percent ?? 0).cgColor
        layoutFill(animated: true)
    }

    private func layoutFill(animated: Bool) {
        let ratio = CGFloat(min(max((percent ?? 0) / 100, 0), 1))
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.8)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        fill.frame = CGRect(x: 0, y: 0, width: track.bounds.width * ratio, height: track.bounds.height)
        CATransaction.commit()
    }

    func animateIn() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame.size.width = 0
        CATransaction.commit()
        DispatchQueue.main.async { self.layoutFill(animated: true) }
    }
}
