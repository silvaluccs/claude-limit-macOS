import AppKit

extension NSTouchBarItem.Identifier {
    static let claudeTray = NSTouchBarItem.Identifier("dev.silvaluccs.claudetouchbar.tray")
    static let claudeIcon = NSTouchBarItem.Identifier("dev.silvaluccs.claudetouchbar.icon")
    static let usagePager = NSTouchBarItem.Identifier("dev.silvaluccs.claudetouchbar.usage")
    static let status = NSTouchBarItem.Identifier("dev.silvaluccs.claudetouchbar.status")
}

/// Controla o ícone fixo na Control Strip e o painel expandido com o uso.
final class TouchBarController: NSObject, NSTouchBarDelegate {
    var onRefreshRequested: (() -> Void)?

    private let trayIcon = ClawdView(showsPercent: false)
    private lazy var trayItem: NSCustomTouchBarItem = {
        let item = NSCustomTouchBarItem(identifier: .claudeTray)
        item.view = trayIcon
        return item
    }()

    private let panelIcon = ClawdView(showsPercent: false)
    private let sessionGauge = UsageGaugeView(title: "Sessão")
    private let weeklyGauge = UsageGaugeView(title: "Semana")
    private lazy var pager = UsagePagerView(pages: [sessionGauge, weeklyGauge])
    private let statusLabel = NSTextField(labelWithString: "")
    private lazy var panel: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [.claudeIcon, .usagePager, .flexibleSpace, .status]
        return bar
    }()

    private(set) var isPanelOpen = false
    private var snapshot: UsageSnapshot?

    func install() {
        trayIcon.onTap = { [weak self] in self?.togglePanel() }
        panelIcon.onTap = { [weak self] in self?.closePanel() }
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = Theme.secondaryText

        // Sem o "X" do sistema: ele fechava o painel e tirava o ícone da Touch Bar.
        // Para fechar, basta tocar no Clawd do painel.
        PrivateTouchBar.showsCloseBoxWhenFrontmost(false)
        PrivateTouchBar.addSystemTrayItem(trayItem)
        PrivateTouchBar.setControlStripPresence(.claudeTray, true)
    }

    func uninstall() {
        closePanel()
        PrivateTouchBar.setControlStripPresence(.claudeTray, false)
        PrivateTouchBar.removeSystemTrayItem(trayItem)
    }

    // MARK: - Painel

    func togglePanel() {
        isPanelOpen ? closePanel() : openPanel()
    }

    func openPanel() {
        onRefreshRequested?()
        PrivateTouchBar.presentSystemModal(panel, trayIdentifier: .claudeTray)
        isPanelOpen = true
        render()
        pager.show(index: 0, animated: false)
        sessionGauge.animateIn()
        panelIcon.playTapAnimation()
    }

    func closePanel() {
        guard isPanelOpen else { return }
        PrivateTouchBar.dismissSystemModal(panel)
        isPanelOpen = false
        // Garante que o ícone continue fixo na Control Strip depois de fechar.
        PrivateTouchBar.setControlStripPresence(.claudeTray, true)
    }

    // MARK: - Dados

    func update(snapshot: UsageSnapshot, isWorking: Bool) {
        self.snapshot = snapshot
        for icon in [trayIcon, panelIcon] {
            icon.update(sessionPercent: snapshot.session?.percent,
                        peakPercent: snapshot.peakPercent,
                        isWorking: isWorking)
        }
        render()
    }

    func show(error: Error) {
        statusLabel.stringValue = error.localizedDescription
        statusLabel.textColor = Theme.warning
    }

    private func render() {
        guard let snapshot else {
            sessionGauge.update(percent: nil, detail: "carregando…")
            weeklyGauge.update(percent: nil, detail: "")
            return
        }
        sessionGauge.update(percent: snapshot.session?.percent,
                            detail: Format.relativeReset(snapshot.session?.resetsAt))
        weeklyGauge.update(percent: snapshot.weekly?.percent,
                           detail: Format.weekdayReset(snapshot.weekly?.resetsAt))
        let time = DateFormatter.localizedString(from: snapshot.fetchedAt, dateStyle: .none, timeStyle: .short)
        statusLabel.stringValue = "atualizado \(time)"
        statusLabel.textColor = Theme.secondaryText
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: identifier)
        switch identifier {
        case .claudeIcon: item.view = panelIcon
        case .usagePager: item.view = pager
        case .status: item.view = statusLabel
        default: return nil
        }
        return item
    }
}
