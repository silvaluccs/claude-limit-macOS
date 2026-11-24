import AppKit
import QuartzCore

final class ClawdView: NSButton {
    var onTap: (() -> Void)?

    private enum Move: CaseIterable {
        case blink, lookAround, jump, wave, dance, walk, squash, sunglasses, sleep, celebrate, shiver, coffee
    }

    private let character = CALayer()
    private let body = CAShapeLayer()
    private let leftEye = CALayer()
    private let rightEye = CALayer()
    private let leftArm = CALayer()
    private let rightArm = CALayer()
    private let legs = (0..<4).map { _ in CALayer() }
    private let glasses = CAShapeLayer()
    private let glints = CAShapeLayer()
    private let zzz = CATextLayer()
    private let mug = CALayer()
    private let mugCup = CAShapeLayer()
    private let mugCoffee = CAShapeLayer()
    private let steam = (0..<2).map { _ in CALayer() }
    private let tempo: CFTimeInterval = 1.4

    private var unit: CGFloat = 2
    private var working = false
    private var lastMove: Move?
    private var bag: [Move] = []
    private var nextMove: DispatchWorkItem?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        target = self
        action = #selector(tapped)
        wantsLayer = true
        layer?.masksToBounds = false

        body.fillColor = Theme.claude.cgColor
        for l in [leftArm, rightArm] + legs { l.backgroundColor = Theme.claude.cgColor }
        for l in [leftEye, rightEye] { l.backgroundColor = NSColor.black.cgColor }
        glasses.fillColor = NSColor.black.cgColor
        glints.fillColor = NSColor.white.cgColor
        glasses.addSublayer(glints)
        glasses.opacity = 0

        mugCup.fillColor = NSColor.white.cgColor
        mugCoffee.fillColor = NSColor(srgbRed: 0.45, green: 0.27, blue: 0.16, alpha: 1).cgColor
        for l in steam { l.backgroundColor = NSColor(white: 1, alpha: 0.7).cgColor; l.opacity = 0 }
        for l in [mugCup, mugCoffee] + steam { mug.addSublayer(l) }
        mug.opacity = 0

        zzz.string = "z"
        zzz.font = NSFont.systemFont(ofSize: 9, weight: .heavy)
        zzz.fontSize = 9
        zzz.foregroundColor = Theme.text.cgColor
        zzz.contentsScale = 2
        zzz.opacity = 0

        character.addSublayer(body)
        for l in [leftEye, rightEye, leftArm, rightArm, glasses, mug] + legs { character.addSublayer(l) }
        layer?.addSublayer(character)
        layer?.addSublayer(zzz)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 40),
            heightAnchor.constraint(equalToConstant: 30),
        ])
        rebuildGeometry()
        scheduleNextMove(after: 1)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { frame.size }
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {}

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        if changed { rebuildGeometry() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rebuildGeometry()
    }

    private func rebuildGeometry() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        unit = 2
        let size = CGSize(width: CGFloat(ClawdSprite.cols) * unit, height: CGFloat(ClawdSprite.rows) * unit)
        character.frame = CGRect(x: (bounds.width - size.width) / 2, y: 3, width: size.width, height: size.height)
        body.frame = character.bounds
        body.path = ClawdSprite.path(ClawdSprite.bodyCells, unit: unit)
        leftEye.frame = ClawdSprite.rect(ClawdSprite.leftEye, unit: unit)
        rightEye.frame = ClawdSprite.rect(ClawdSprite.rightEye, unit: unit)
        leftArm.frame = ClawdSprite.rect(ClawdSprite.leftArm, unit: unit)
        rightArm.frame = ClawdSprite.rect(ClawdSprite.rightArm, unit: unit)
        for (leg, cell) in zip(legs, ClawdSprite.legs) { leg.frame = ClawdSprite.rect(cell, unit: unit) }
        glasses.frame = character.bounds
        glasses.path = ClawdSprite.path(ClawdSprite.glasses, unit: unit)
        glints.frame = character.bounds
        glints.path = ClawdSprite.path(ClawdSprite.glassesGlints, unit: unit)
        mug.frame = character.bounds
        mugCup.path = ClawdSprite.path([ClawdSprite.mugCup], unit: unit)
        mugCoffee.path = ClawdSprite.path([ClawdSprite.mugCoffee], unit: unit)
        for (l, cell) in zip(steam, ClawdSprite.steam) { l.frame = ClawdSprite.rect(cell, unit: unit) }
        zzz.frame = CGRect(x: character.frame.maxX - 6, y: character.frame.maxY - 4, width: 8, height: 11)
        startBlinking()
    }

    func update(isWorking: Bool) {
        working = isWorking
    }

    func playTapAnimation() {
        perform(.jump)
    }

    @objc private func tapped() {
        playTapAnimation()
        onTap?()
    }

    private func scheduleNextMove(after delay: TimeInterval) {
        nextMove?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.performRandomMove() }
        nextMove = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func performRandomMove() {
        let pool: [Move] = working
            ? [.dance, .jump, .celebrate, .walk, .sunglasses, .wave, .squash]
            : Move.allCases
        let move = drawFromBag(pool: pool)
        lastMove = move
        let duration = perform(move) / tempo
        let pause = working ? Double.random(in: 0.3...0.9) : Double.random(in: 1.2...3)
        scheduleNextMove(after: duration + pause)
    }

    private func drawFromBag(pool: [Move]) -> Move {
        bag.removeAll { !pool.contains($0) }
        if bag.isEmpty {
            bag = pool.shuffled()
            if bag.count > 1, bag.last == lastMove {
                bag.swapAt(0, bag.count - 1)
            }
        }
        return bag.removeLast()
    }

    @discardableResult
    private func perform(_ move: Move) -> CFTimeInterval {
        let u = unit
        switch move {
        case .blink:
            for eye in [leftEye, rightEye] {
                eye.add(keyframes("transform.scale.y", [1, 0.15, 1, 0.15, 1], duration: 0.5), forKey: "move")
            }
            return 0.5

        case .lookAround:
            for eye in [leftEye, rightEye] {
                eye.add(keyframes("position.x", [0, -u, -u, u, u, 0], duration: 2.4, additive: true, discrete: true),
                        forKey: "move")
            }
            return 2.4

        case .jump:
            character.add(keyframes("position.y", [0, u * 4, u * 4.5, 0, u * 1.5, 0],
                                    times: [0, 0.3, 0.42, 0.7, 0.85, 1], duration: 0.7, additive: true),
                          forKey: "jump")
            for arm in [leftArm, rightArm] {
                arm.add(keyframes("position.y", [0, u, 0], duration: 0.7, additive: true, discrete: true), forKey: "move")
            }
            return 0.7

        case .wave:
            rightArm.add(keyframes("position.y", [0, u * 2, u * 3, u * 2, u * 3, u * 2, u * 3, 0],
                                   duration: 1.8, additive: true, discrete: true), forKey: "move")
            return 1.8

        case .dance:
            let beats = 8
            let tilt: [CGFloat] = (0...beats).map { $0 == 0 || $0 == beats ? 0 : ($0 % 2 == 0 ? 0.18 : -0.18) }
            character.add(keyframes("transform.rotation.z", tilt, duration: 2.4, discrete: true), forKey: "move")
            let up = (0...beats).map { $0 == beats ? 0 : ($0 % 2 == 0 ? u * 2 : 0) }
            let down = (0...beats).map { $0 == beats ? 0 : ($0 % 2 == 0 ? 0 : u * 2) }
            leftArm.add(keyframes("position.y", up, duration: 2.4, additive: true, discrete: true), forKey: "move")
            rightArm.add(keyframes("position.y", down, duration: 2.4, additive: true, discrete: true), forKey: "move")
            return 2.4

        case .walk:
            let steps: [CGFloat] = [0, -u, -u * 2, -u, 0, u, u * 2, u, 0]
            character.add(keyframes("position.x", steps, duration: 3, additive: true, discrete: true), forKey: "move")
            for (i, leg) in legs.enumerated() {
                let lift = (0...8).map { $0 == 8 ? 0 : (($0 + i) % 2 == 0 ? u : 0) }
                leg.add(keyframes("position.y", lift, duration: 3, additive: true, discrete: true), forKey: "move")
            }
            return 3

        case .squash:
            character.add(keyframes("transform.scale.y", [1, 0.75, 1.15, 0.95, 1], duration: 0.8), forKey: "move")
            character.add(keyframes("transform.scale.x", [1, 1.15, 0.9, 1.03, 1], duration: 0.8), forKey: "move2")
            return 0.8

        case .sunglasses:
            let total: CFTimeInterval = 6
            glasses.add(keyframes("position.y", [u * 8, 0, 0, u * 8], times: [0, 0.1, 0.9, 1],
                                  duration: total, additive: true), forKey: "move")
            glasses.add(keyframes("opacity", [0, 1, 1, 0], times: [0, 0.04, 0.96, 1], duration: total), forKey: "fade")
            let nods = (0...12).map { $0 % 2 == 0 ? 0 : -u * 0.5 }
            character.add(keyframes("position.y", nods, duration: total, additive: true, discrete: true), forKey: "move")
            let glint = keyframes("opacity", [1, 0.2, 1], duration: 0.8)
            glint.repeatCount = Float(total / 0.8)
            glints.add(glint, forKey: "glint")
            return total

        case .sleep:
            let total: CFTimeInterval = 5
            for eye in [leftEye, rightEye] {
                eye.add(keyframes("transform.scale.y", [1, 0.15, 0.15, 1], times: [0, 0.08, 0.92, 1], duration: total),
                        forKey: "move")
            }
            character.add(keyframes("transform.scale.y", [1, 0.95, 1, 0.95, 1, 0.95, 1], duration: total), forKey: "move")
            let floatUp = CAAnimationGroup()
            floatUp.animations = [
                keyframes("position.y", [0, u * 3], duration: 1.6, additive: true),
                keyframes("opacity", [0, 1, 0], duration: 1.6),
            ]
            floatUp.duration = 1.6 / tempo
            floatUp.repeatCount = 3
            floatUp.beginTime = CACurrentMediaTime() + 0.4 / tempo
            zzz.add(floatUp, forKey: "move")
            return total

        case .celebrate:
            for arm in [leftArm, rightArm] {
                arm.add(keyframes("position.y", [0, u * 3, u * 2, u * 3, u * 2, u * 3, 0],
                                  duration: 1.4, additive: true, discrete: true), forKey: "move")
            }
            character.add(keyframes("position.y", [0, u * 3, 0, u * 3, 0], duration: 1.4, additive: true), forKey: "jump")
            return 1.4

        case .coffee:
            let total: CFTimeInterval = 3.4
            let times: [NSNumber] = [0, 0.12, 0.25, 0.42, 0.52, 0.65, 0.82, 0.9, 1]
            mug.add(keyframes("opacity", [0, 1, 1, 1, 1, 1, 1, 1, 0], times: times, duration: total), forKey: "fade")
            mug.add(keyframes("position.x", [0, 0, -u * 2, -u * 2, 0, -u * 2, -u * 2, 0, 0], times: times,
                              duration: total, additive: true), forKey: "moveX")
            mug.add(keyframes("position.y", [0, 0, u * 2, u * 2, 0, u * 2, u * 2, 0, 0], times: times,
                              duration: total, additive: true), forKey: "moveY")
            rightArm.add(keyframes("position.y", [0, 0, u * 2, u * 2, 0, u * 2, u * 2, 0, 0], times: times,
                                   duration: total, additive: true), forKey: "move")
            for eye in [leftEye, rightEye] {
                eye.add(keyframes("transform.scale.y", [1, 1, 0.3, 0.3, 1, 0.3, 0.3, 1, 1], times: times,
                                  duration: total), forKey: "move")
            }
            for (i, puff) in steam.enumerated() {
                let rise = CAAnimationGroup()
                rise.animations = [
                    keyframes("position.y", [0, u * 2], duration: 0.9, additive: true),
                    keyframes("position.x", [0, u * 0.5, -u * 0.5, 0], duration: 0.9, additive: true),
                    keyframes("opacity", [0, 1, 0], duration: 0.9),
                ]
                rise.duration = 0.9 / tempo
                rise.repeatCount = 3
                rise.beginTime = CACurrentMediaTime() + (0.15 + Double(i) * 0.45) / tempo
                puff.add(rise, forKey: "move")
            }
            return total

        case .shiver:
            let shake = (0...12).map { $0 == 12 ? 0 : ($0 % 2 == 0 ? u * 0.5 : -u * 0.5) }
            character.add(keyframes("position.x", shake, duration: 0.6, additive: true, discrete: true), forKey: "move")
            return 0.6
        }
    }

    private func startBlinking() {
        for eye in [leftEye, rightEye] {
            let blink = keyframes("transform.scale.y", [1, 1, 0.15, 1], times: [0, 0.93, 0.96, 1], duration: 4.2)
            blink.repeatCount = .infinity
            eye.add(blink, forKey: "blink")
        }
    }

    private func keyframes(_ keyPath: String, _ values: [CGFloat], times: [NSNumber]? = nil,
                           duration: CFTimeInterval, additive: Bool = false,
                           discrete: Bool = false) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = values
        a.keyTimes = times
        a.duration = duration / tempo
        a.isAdditive = additive
        if discrete { a.calculationMode = .discrete }
        return a
    }
}
