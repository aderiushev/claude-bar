import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var refreshLoop: Task<Void, Never>?
    private let cacheURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/usage-cache.json")

    private var displayMode: DisplayMode {
        get { DisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "") ?? .week }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "displayMode")
            statusItem.menu = makeMenu()
            startRefreshLoop()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "com.aderiushev.claude-bar"
        statusItem.button?.title = "…"
        statusItem.menu = makeMenu()

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
        menu.addItem(withTitle: "Quit claude-bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func switchToWeek()    { displayMode = .week }
    @objc private func switchToSession() { displayMode = .session }

    private func startRefreshLoop() {
        refreshLoop?.cancel()
        refreshLoop = Task {
            while !Task.isCancelled {
                await updateTitle()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
            }
        }
    }

    @objc private func handleWake() {
        startRefreshLoop()
    }

    private func updateTitle() async {
        let url = cacheURL
        let mode = displayMode
        let snapshot = await Task.detached(priority: .utility) {
            UsageReader.readOrEmpty(from: url)
        }.value
        let title = StatusFormatter.format(snapshot, mode: mode)
        if statusItem.button?.title != title {
            statusItem.button?.title = title
        }
    }
}
