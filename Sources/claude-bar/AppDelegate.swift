import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var refreshLoop: Task<Void, Never>?
    private var lastFetchedAt: Date?
    private var lastError: String?

    private static let fetchInterval: TimeInterval = 5 * 60
    private static let displayTick: Duration = .seconds(30)
    private static let needsCookieTitle = "🔑"

    private var displayMode: DisplayMode {
        get { DisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "") ?? .week }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "displayMode")
            statusItem.menu = makeMenu()
            startRefreshLoop()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        Log.info("launch v\(version) build \(build) — log file: \(Log.fileURL.path)")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "com.aderiushev.claude-bar"
        statusItem.button?.title = "…"
        statusItem.menu = makeMenu()

        lastFetchedAt = UsageCache.fetchedAt()
        startRefreshLoop()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let weekItem = NSMenuItem(title: "Week view", action: #selector(switchToWeek), keyEquivalent: "")
        weekItem.state = displayMode == .week ? .on : .off
        menu.addItem(weekItem)

        let sessionItem = NSMenuItem(title: "Session view", action: #selector(switchToSession), keyEquivalent: "")
        sessionItem.state = displayMode == .session ? .on : .off
        menu.addItem(sessionItem)

        menu.addItem(.separator())

        if let err = lastError {
            let header = NSMenuItem(title: err, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }
        menu.addItem(withTitle: "Open claude.ai (in Chrome) →", action: #selector(openClaudeInChrome), keyEquivalent: "")
        menu.addItem(withTitle: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        menu.addItem(withTitle: "Reveal log…", action: #selector(revealLog), keyEquivalent: "")

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit claude-bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func switchToWeek()    { displayMode = .week }
    @objc private func switchToSession() { displayMode = .session }

    @objc private func refreshNow() {
        lastFetchedAt = nil
        Task { @MainActor in await tick() }
    }

    @objc private func openClaudeInChrome() {
        let url = URL(string: "https://claude.ai/")!
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        if FileManager.default.fileExists(atPath: chrome.path) {
            let cfg = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: cfg)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func revealLog() {
        NSWorkspace.shared.activateFileViewerSelecting([Log.fileURL])
    }

    @objc private func handleWake() {
        startRefreshLoop()
    }

    private func startRefreshLoop() {
        refreshLoop?.cancel()
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                do {
                    try await Task.sleep(for: Self.displayTick)
                } catch {
                    break
                }
            }
        }
    }

    private func tick() async {
        await maybeFetch()
        renderTitle()
    }

    private func maybeFetch() async {
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < Self.fetchInterval {
            return
        }
        do {
            let result = try await Task.detached(priority: .utility) {
                try await UsageFetcher.fetch()
            }.value
            let now = Date()
            try UsageCache.write(result.snapshot, orgUUID: result.orgUUID, fetchedAt: now)
            lastFetchedAt = now
            lastError = nil
            Log.info("fetch ok: session=\(result.snapshot.sessionPct ?? -1)%% week=\(result.snapshot.weekPct ?? -1)%%")
        } catch FetchError.noChromeCookies {
            lastError = "Chrome not found"
            Log.info("no chrome cookies available")
        } catch FetchError.missingSessionKey {
            lastError = "Not signed in to Chrome"
            Log.info("chrome has no sessionKey — open claude.ai in chrome")
        } catch FetchError.unauthorized {
            lastError = "Session expired in Chrome"
            Log.info("session expired — open claude.ai in chrome to refresh")
        } catch {
            lastError = "Fetch failed"
            Log.info("fetch failed: \(error)")
        }
        statusItem.menu = makeMenu()
    }

    private func renderTitle() {
        let snapshot = UsageCache.read()
        let formatted = StatusFormatter.format(snapshot, mode: displayMode)
        let title: String
        if formatted == "--", lastError != nil {
            title = Self.needsCookieTitle
        } else {
            title = formatted
        }
        if statusItem.button?.title != title {
            statusItem.button?.title = title
        }
    }
}
