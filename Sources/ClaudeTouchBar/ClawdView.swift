import AppKit
import QuartzCore

/// Clawd digitando no notebook, desenhado com Core Animation, opcionalmente
/// com o percentual da sessão ao lado.
///
/// - ocioso: digita devagar e pisca de vez em quando;
/// - trabalhando (uso da sessão subindo): digita rápido e balança o corpo;
/// - toque: dá um pulinho.
///
/// É um `NSButton` sem borda porque, na Control Strip, o toque via target/action
/// é o caminho confiável. A geometria é montada em `setFrameSize` e não em
/// `layout()`, que o sistema não chama para itens da Control Strip.
final class ClawdView: NSButton {
    var onTap: (() -> Void)?

    private let showsPercent: Bool
    private let sprite = CALayer()
    private let character = CALayer()
    private let body = CAShapeLayer()
    private let leftEye = CALayer()
    private let rightEye = CALayer()
    private let leftArm = CALayer()
    private let rightArm = CALayer()
    private let lid = CALayer()
    private let base = CALayer()
    private let lidLogo = CALayer()
    private let percentLayer = CATextLayer()

    private var unit: CGFloat = 2
    private var working = false

    init(height: CGFloat = 30, showsPercent: Bool) {
        self.showsPercent = showsPercent
        let width: CGFloat = showsPercent ? 74 : 40
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        target = self
        action = #selector(tapped)
        wantsLayer = true
        layer?.masksToBounds = false

        body.fillColor = Theme.claude.cgColor
        for l in [leftArm, rightArm] { l.backgroundColor = Theme.claude.cgColor }
        for l in [leftEye, rightEye] { l.backgroundColor = NSColor.black.cgColor }
        lid.backgroundColor = NSColor(white: 0.62, alpha: 1).cgColor
        base.backgroundColor = NSColor(white: 0.8, alpha: 1).cgColor
        lidLogo.backgroundColor = Theme.claude.cgColor

        character.addSublayer(body)
        for l in [leftEye, rightEye, leftArm, rightArm] { character.addSublayer(l) }
        sprite.addSublayer(character)
        for l in [lid, base, lidLogo] { sprite.addSublayer(l) }
        layer?.addSublayer(sprite)

        percentLayer.fontSize = 13
        percentLayer.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        percentLayer.foregroundColor = Theme.text.cgColor
        percentLayer.alignmentMode = .left
        percentLayer.contentsScale = 2
        percentLayer.string = "--%"
        percentLayer.isHidden = !showsPercent
        layer?.addSublayer(percentLayer)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: height),
        ])
        rebuildGeometry()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { frame.size }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        if changed { rebuildGeometry() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rebuildGeometry()
    }

    // O NSButton usa coordenadas invertidas (y para baixo), o que deixava o
    // sprite de cabeça para baixo. O sprite é montado com y para cima.
    override var isFlipped: Bool { false }

    // Só os layers desenham; o NSButton não deve pintar fundo ao ser tocado.
    override func draw(_ dirtyRect: NSRect) {}

    // MARK: - Geometria

    private func rebuildGeometry() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        // Tamanho do pixel em passos de 0,5 pt (1 px físico na tela retina).
        let u = (bounds.height * 0.9 / CGFloat(ClawdSprite.rows) * 2).rounded(.down) / 2
        unit = max(u, 1)
        let size = CGSize(width: CGFloat(ClawdSprite.cols) * unit, height: CGFloat(ClawdSprite.rows) * unit)
        let x = showsPercent ? 2 : (bounds.width - size.width) / 2
        sprite.frame = CGRect(origin: CGPoint(x: x, y: (bounds.height - size.height) / 2), size: size)
        character.frame = sprite.bounds

        body.frame = sprite.bounds
        body.path = ClawdSprite.path(ClawdSprite.bodyCells, unit: unit)
        leftEye.frame = ClawdSprite.rect(ClawdSprite.leftEye, unit: unit)
        rightEye.frame = ClawdSprite.rect(ClawdSprite.rightEye, unit: unit)
        leftArm.frame = ClawdSprite.rect(ClawdSprite.leftArm, unit: unit)
        rightArm.frame = ClawdSprite.rect(ClawdSprite.rightArm, unit: unit)
        lid.frame = ClawdSprite.rect(ClawdSprite.lid, unit: unit)
        lid.cornerRadius = unit * 0.6
        base.frame = ClawdSprite.rect(ClawdSprite.base, unit: unit)
        base.cornerRadius = unit * 0.4
        lidLogo.frame = ClawdSprite.rect(ClawdSprite.lidLogo, unit: unit)

        let textHeight: CGFloat = 17
        percentLayer.frame = CGRect(x: sprite.frame.maxX + 4, y: (bounds.height - textHeight) / 2 - 1,
                                    width: bounds.width - sprite.frame.maxX - 4, height: textHeight)
        startAnimations()
    }

    // MARK: - Estado

    func update(sessionPercent: Double?, peakPercent: Double, isWorking: Bool) {
        percentLayer.string = Format.percent(sessionPercent)
        let color = Theme.color(forPercent: peakPercent)
        percentLayer.foregroundColor = (peakPercent < 70 ? Theme.text : color).cgColor
        lidLogo.backgroundColor = color.cgColor
        if isWorking != working {
            working = isWorking
            startAnimations()
        }
    }

    // MARK: - Animações

    private func startAnimations() {
        let period: CFTimeInterval = working ? 0.22 : 0.7

        // Braços digitando, alternados (movimento de 1 pixel, discreto).
        for (arm, offset) in [(leftArm, 0.0), (rightArm, period / 2)] {
            let type = CAKeyframeAnimation(keyPath: "position.y")
            type.values = [0, -unit, 0]
            type.keyTimes = [0, 0.5, 1]
            type.calculationMode = .discrete
            type.isAdditive = true
            type.duration = period
            type.repeatCount = .infinity
            type.beginTime = CACurrentMediaTime() + offset
            arm.add(type, forKey: "typing")
        }

        // Piscar.
        for eye in [leftEye, rightEye] {
            let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
            blink.values = [1, 1, 0.15, 1]
            blink.keyTimes = [0, 0.93, 0.96, 1]
            blink.duration = working ? 2.4 : 3.8
            blink.repeatCount = .infinity
            eye.add(blink, forKey: "blink")
        }

        // Corpo balança quando está trabalhando.
        if working {
            let bob = CAKeyframeAnimation(keyPath: "position.y")
            bob.values = [0, unit, 0]
            bob.keyTimes = [0, 0.5, 1]
            bob.calculationMode = .discrete
            bob.isAdditive = true
            bob.duration = period * 2
            bob.repeatCount = .infinity
            character.add(bob, forKey: "bob")
        } else {
            character.removeAnimation(forKey: "bob")
        }

        // Logo da tampa "respirando".
        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = 1
        glow.toValue = 0.35
        glow.duration = working ? 0.5 : 1.4
        glow.autoreverses = true
        glow.repeatCount = .infinity
        lidLogo.add(glow, forKey: "glow")
    }

    func playTapAnimation() {
        let jump = CAKeyframeAnimation(keyPath: "position.y")
        jump.values = [0, unit * 3, unit * 3.5, 0]
        jump.keyTimes = [0, 0.35, 0.5, 1]
        jump.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeIn),
        ]
        jump.isAdditive = true
        jump.duration = 0.4
        character.add(jump, forKey: "jump")
    }

    @objc private func tapped() {
        playTapAnimation()
        onTap?()
    }
}
