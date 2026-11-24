import AppKit

enum Theme {
    /// Laranja "terracota" do Claude.
    static let claude = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)
    static let warning = NSColor(srgbRed: 0.96, green: 0.76, blue: 0.26, alpha: 1)
    static let danger = NSColor(srgbRed: 0.93, green: 0.33, blue: 0.31, alpha: 1)
    static let track = NSColor(white: 1, alpha: 0.18)
    static let text = NSColor(white: 1, alpha: 0.92)
    static let secondaryText = NSColor(white: 1, alpha: 0.6)

    static func color(forPercent p: Double) -> NSColor {
        switch p {
        case ..<70: return claude
        case ..<90: return warning
        default: return danger
        }
    }
}

enum Format {
    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE HH:mm"
        return f
    }()

    static func percent(_ p: Double?) -> String {
        guard let p else { return "--%" }
        return "\(Int(p.rounded()))%"
    }

    /// "reseta em 2h10" para a sessão.
    static func relativeReset(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        if minutes < 60 { return "reseta em \(minutes)min" }
        return "reseta em \(minutes / 60)h\(String(format: "%02d", minutes % 60))"
    }

    /// "reseta dom 18:59" para a semana.
    static func weekdayReset(_ date: Date?) -> String {
        guard let date else { return "" }
        return "reseta " + weekday.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}
