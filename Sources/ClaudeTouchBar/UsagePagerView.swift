import AppKit
import QuartzCore

/// Mostra uma barra de uso por vez (Sessão ou Semana). Um toque ou um deslize
/// troca de página com uma animação de "subida": a atual sai por cima e a
/// próxima entra por baixo. A Touch Bar só detecta movimento horizontal, então
/// o gesto é toque/deslize lateral e a subida fica por conta da animação.
final class UsagePagerView: NSView {
    let pages: [UsageGaugeView]
    private(set) var index = 0
    private var dots: [CALayer] = []
    private let dotsWidth: CGFloat = 14
    private var isAnimating = false

    init(pages: [UsageGaugeView]) {
        self.pages = pages
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        allowedTouchTypes = [.direct]

        for page in pages {
            page.translatesAutoresizingMaskIntoConstraints = true
            addSubview(page)
        }
        for _ in pages {
            let dot = CALayer()
            dot.cornerRadius = 2
            layer?.addSublayer(dot)
            dots.append(dot)
        }
        updateDots()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let gauge = pages.first?.intrinsicContentSize ?? .zero
        return NSSize(width: gauge.width + dotsWidth, height: 30)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutPages()
    }

    override func layout() {
        super.layout()
        layoutPages()
    }

    private func pageFrame(offset: CGFloat) -> NSRect {
        NSRect(x: 0, y: offset, width: bounds.width - dotsWidth, height: bounds.height)
    }

    private func layoutPages() {
        guard !isAnimating else { return }
        for (i, page) in pages.enumerated() {
            page.frame = pageFrame(offset: 0)
            page.isHidden = i != index
        }
        // Pontinhos empilhados na vertical, reforçando a ideia de "subir".
        let size: CGFloat = 4, gap: CGFloat = 4
        let total = CGFloat(dots.count) * size + CGFloat(dots.count - 1) * gap
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, dot) in dots.enumerated() {
            dot.frame = CGRect(x: bounds.width - dotsWidth / 2 - size / 2,
                               y: (bounds.height + total) / 2 - size - CGFloat(i) * (size + gap),
                               width: size, height: size)
        }
        CATransaction.commit()
    }

    private func updateDots() {
        for (i, dot) in dots.enumerated() {
            dot.backgroundColor = (i == index ? Theme.text : Theme.track).cgColor
        }
    }

    // MARK: - Navegação

    func show(index newIndex: Int, animated: Bool) {
        guard pages.indices.contains(newIndex) else { return }
        guard animated, newIndex != index, window != nil else {
            index = newIndex
            updateDots()
            needsLayout = true
            layoutPages()
            return
        }
        let current = pages[index]
        let next = pages[newIndex]
        index = newIndex
        updateDots()
        isAnimating = true

        let h = bounds.height
        next.frame = pageFrame(offset: -h)
        next.isHidden = false
        next.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            current.animator().frame = pageFrame(offset: h)
            current.animator().alphaValue = 0
            next.animator().frame = pageFrame(offset: 0)
            next.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            current.isHidden = true
            current.alphaValue = 1
            self?.isAnimating = false
            self?.layoutPages()
            next.animateIn()
        })
    }

    func showNext() {
        show(index: (index + 1) % pages.count, animated: true)
    }

    // MARK: - Toque

    override func touchesEnded(with event: NSEvent) {
        showNext()
    }
}
