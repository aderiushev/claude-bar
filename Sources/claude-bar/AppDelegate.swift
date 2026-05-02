import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var refreshLoop: Task<Void, Never>?

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
        menu.addItem(withTitle: "Quit claude-bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

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
        let cacheURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude/usage-cache.json")
        let snapshot = await Task.detached(priority: .utility) {
            UsageReader.readOrEmpty(from: cacheURL)
        }.value
        statusItem.button?.title = StatusFormatter.format(snapshot)
    }
}
