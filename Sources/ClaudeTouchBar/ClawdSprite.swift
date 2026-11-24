import CoreGraphics

enum ClawdSprite {
    typealias Cell = (col: Int, row: Int, w: Int, h: Int)

    static let cols = 16
    static let rows = 10

    static let leftEye: Cell = (4, 2, 1, 2)
    static let rightEye: Cell = (11, 2, 1, 2)
    static let leftArm: Cell = (0, 4, 2, 2)
    static let rightArm: Cell = (14, 4, 2, 2)
    static let legs: [Cell] = [(3, 8, 1, 2), (5, 8, 1, 2), (10, 8, 1, 2), (12, 8, 1, 2)]
    static let glasses: [Cell] = [(3, 2, 4, 2), (9, 2, 4, 2), (7, 2, 2, 1)]
    static let glassesGlints: [Cell] = [(4, 2, 1, 1), (10, 2, 1, 1)]
    static let mugCup: Cell = (16, 4, 2, 2)
    static let mugCoffee: Cell = (16, 3, 2, 1)
    static let steam: [Cell] = [(16, 2, 1, 1), (17, 1, 1, 1)]

    static var bodyCells: [Cell] {
        var cells: [Cell] = []
        for row in 0..<8 {
            for col in 2..<14 {
                let isEye = (col == leftEye.col || col == rightEye.col) && (2...3).contains(row)
                if !isEye { cells.append((col, row, 1, 1)) }
            }
        }
        return cells
    }

    static func rect(_ c: Cell, unit u: CGFloat) -> CGRect {
        CGRect(x: CGFloat(c.col) * u,
               y: CGFloat(rows - c.row - c.h) * u,
               width: CGFloat(c.w) * u,
               height: CGFloat(c.h) * u)
    }

    static func path(_ cells: [Cell], unit u: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for c in cells { p.addRect(rect(c, unit: u)) }
        return p
    }

    static func standingPath(unit u: CGFloat) -> CGPath {
        path(bodyCells + [leftArm, rightArm] + legs, unit: u)
    }
}
