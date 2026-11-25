import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service = UsageService()
    private let touchBar = TouchBarController()
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var backoffLevel = 0

    private var snapshot: UsageSnapshot?
    private var lastIncreaseAt: Date?
    private var lastFetchAt: Date?
    private var isFetching = false

    private let pollInterval: TimeInterval = 5 * 60
    private let minManualInterval: TimeInterval = 2 * 60
    private let maxBackoff: TimeInterval = 30 * 60
    private let workingWindow: TimeInterval = 6 * 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        touchBar.onRefreshRequested = { [weak self] in self?.refresh(force: false) }
        touchBar.install()

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
        if backoffLevel > 0, let timer, timer.fireDate > Date() { return }
        if !force, let last = lastFetchAt, Date().timeIntervalSince(last) < minManualInterval { return }
        isFetching = true
        Task { @MainActor in
            defer { isFetching = false; lastFetchAt = Date() }
            do {
                let new = try await service.fetch()
                backoffLevel = 0
                apply(new)
                scheduleNextFetch(after: pollInterval)
            } catch UsageError.rateLimited(let retryAfter) {
                backoffLevel += 1
                let exponential = min(pollInterval * pow(2, Double(backoffLevel - 1)), maxBackoff)
                let wait = max(retryAfter ?? 0, exponential)
                scheduleNextFetch(after: wait)
                let time = DateFormatter.localizedString(from: Date().addingTimeInterval(wait),
                                                         dateStyle: .none, timeStyle: .short)
                report(message: "Muitas consultas, tentando de novo às \(time)")
            } catch {
                scheduleNextFetch(after: pollInterval)
                report(message: error.localizedDescription)
            }
        }
    }

    private func scheduleNextFetch(after interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh(force: true)
        }
    }

    private func report(message: String) {
        let error = NSError(domain: "ClaudeTouchBar", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        touchBar.show(error: error)
        statusItem.button?.toolTip = message
        updateMenu(error: error)
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
