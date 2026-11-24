import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service = UsageService()
    private let touchBar = TouchBarController()
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private var snapshot: UsageSnapshot?
    private var lastIncreaseAt: Date?
    private var lastFetchAt: Date?
    private var isFetching = false

    private let pollInterval: TimeInterval = 120
    private let workingWindow: TimeInterval = 4 * 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        touchBar.onRefreshRequested = { [weak self] in self?.refresh(force: false) }
        touchBar.install()

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.refresh(force: true)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh(force: true) }

        refresh(force: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBar.uninstall()
    }

    func refresh(force: Bool) {
        if isFetching { return }
        if !force, let last = lastFetchAt, Date().timeIntervalSince(last) < 30 { return }
        isFetching = true
        Task { @MainActor in
            defer { isFetching = false; lastFetchAt = Date() }
            do {
                let new = try await service.fetch()
                apply(new)
            } catch {
                touchBar.show(error: error)
                statusItem.button?.toolTip = error.localizedDescription
                updateMenu(error: error)
            }
        }
    }

    private func apply(_ new: UsageSnapshot) {
        if let old = snapshot?.session?.percent, let cur = new.session?.percent, cur > old {
            lastIncreaseAt = Date()
        }
        snapshot = new
        let working = lastIncreaseAt.map { Date().timeIntervalSince($0) < workingWindow } ?? false
        touchBar.update(snapshot: new, isWorking: working)
        updateStatusItem(new)
        updateMenu(error: nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(size: NSSize(width: 16, height: 10), flipped: false) { _ in
                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.addPath(ClawdSprite.standingPath(unit: 1))
                ctx.fillPath()
                return true
            }
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.title = " --"
        }
        updateMenu(error: nil)
    }

    private func updateStatusItem(_ s: UsageSnapshot) {
        statusItem.button?.title = " \(Format.percent(s.session?.percent)) · \(Format.percent(s.weekly?.percent))"
        statusItem.button?.toolTip = "Sessão · Semana"
    }

    private func updateMenu(error: Error?) {
        let menu = NSMenu()
        func info(_ title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        if let s = snapshot {
            info("Sessão: \(Format.percent(s.session?.percent))  ·  \(Format.relativeReset(s.session?.resetsAt))")
            info("Semana: \(Format.percent(s.weekly?.percent))  ·  \(Format.weekdayReset(s.weekly?.resetsAt))")
            let time = DateFormatter.localizedString(from: s.fetchedAt, dateStyle: .none, timeStyle: .short)
            info("Atualizado às \(time)")
        } else {
            info("Carregando…")
        }
        if let error { info("⚠️ \(error.localizedDescription)") }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Mostrar na Touch Bar", action: #selector(showPanel), keyEquivalent: "t").target = self
        menu.addItem(withTitle: "Atualizar agora", action: #selector(refreshNow), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func showPanel() { touchBar.openPanel() }
    @objc private func refreshNow() { refresh(force: true) }
}
