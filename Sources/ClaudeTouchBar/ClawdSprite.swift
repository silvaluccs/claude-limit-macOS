import CoreGraphics

/// Pixel art do Clawd (mascote do Claude Code), derivada do logo em blocos que
/// aparece no terminal:
///
///      ▐▛███▜▌
///     ▝▜█████▛▘
///       ▘▘ ▝▝
///
/// Cada caractere de quadrante vira 2×2 "pixels" de terminal, e como a célula
/// do terminal é 1:2, cada linha de quadrante vira 2 linhas de pixels quadrados.
/// Grade final: 16 colunas × 10 linhas (de cima para baixo), mais o notebook.
enum ClawdSprite {
    typealias Cell = (col: Int, row: Int, w: Int, h: Int)

    static let cols = 16
    static let rows = 12

    static let leftEye: Cell = (4, 2, 1, 2)
    static let rightEye: Cell = (11, 2, 1, 2)
    static let leftArm: Cell = (0, 4, 2, 2)
    static let rightArm: Cell = (14, 4, 2, 2)
    static let legs: [Cell] = [(3, 8, 1, 2), (5, 8, 1, 2), (10, 8, 1, 2), (12, 8, 1, 2)]

    /// Tampa do notebook (vista por trás) e a base/teclado.
    static let lid: Cell = (4, 7, 8, 4)
    static let base: Cell = (2, 11, 12, 1)
    static let lidLogo: Cell = (7, 8, 2, 1)

    /// Corpo 12×8 com os olhos "vazados".
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

    /// Converte uma célula (linha de cima para baixo) num retângulo com y para cima.
    static func rect(_ c: Cell, unit u: CGFloat, gridRows: Int = rows) -> CGRect {
        CGRect(x: CGFloat(c.col) * u,
               y: CGFloat(gridRows - c.row - c.h) * u,
               width: CGFloat(c.w) * u,
               height: CGFloat(c.h) * u)
    }

    static func path(_ cells: [Cell], unit u: CGFloat, gridRows: Int = rows) -> CGPath {
        let p = CGMutablePath()
        for c in cells { p.addRect(rect(c, unit: u, gridRows: gridRows)) }
        return p
    }

    /// Clawd "de pé", sem notebook (ícone da barra de menus). Grade 16×10.
    static func standingPath(unit u: CGFloat) -> CGPath {
        path(bodyCells + [leftArm, rightArm] + legs, unit: u, gridRows: 10)
    }
}
