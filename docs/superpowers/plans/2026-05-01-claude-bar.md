# claude-bar macOS Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal macOS menu bar app (NSStatusItem) that reads `~/.claude/usage-cache.json` and displays Claude Code quota stats in the format `19→89 [5d]` (session %, weekly %, time to weekly reset) in the system status bar.

**Architecture:** Single `@main` `AppDelegate` owns the `NSStatusItem` and a Swift-concurrency refresh loop (30 s + wake-from-sleep). `UsageReader` does synchronous file I/O off the main actor and returns a `UsageSnapshot` value type. `StatusFormatter` is a pure function `UsageSnapshot → String`. No storyboard, no XIB, no third-party dependencies.

**Tech Stack:** Swift 6.2, AppKit (NSStatusBar / NSStatusItem / NSMenu), Foundation, XCTest, xcodegen 2.x (install via Homebrew).

---

## File Map

| File | Responsibility |
|------|---------------|
| `project.yml` | xcodegen spec — produces `claude-bar.xcodeproj` |
| `Sources/claude-bar/AppDelegate.swift` | `@main` entry, NSStatusItem lifecycle, refresh loop |
| `Sources/claude-bar/UsageSnapshot.swift` | `Sendable` value type for parsed quota data |
| `Sources/claude-bar/UsageReader.swift` | Reads & parses `usage-cache.json` from disk |
| `Sources/claude-bar/StatusFormatter.swift` | Pure `UsageSnapshot → String` formatting |
| `Tests/claude-barTests/StatusFormatterTests.swift` | Unit tests for formatter |
| `Tests/claude-barTests/UsageReaderTests.swift` | Unit tests for reader |
| `Tests/claude-barTests/Fixtures/usage-cache.json` | Test fixture matching real file shape |

---

## Task 1: Project Scaffold

**Files:**
- Create: `project.yml`

- [ ] **Step 1: Install xcodegen**

```bash
brew install xcodegen
```

Expected: `xcodegen version 2.x.x`

- [ ] **Step 2: Write `project.yml`**

```yaml
name: claude-bar
options:
  bundleIdPrefix: com.aderiushev
  deploymentTarget:
    macOS: "13.0"
targets:
  claude-bar:
    type: application
    platform: macOS
    sources: Sources/claude-bar
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.aderiushev.claude-bar
        SWIFT_VERSION: "6.0"
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        CODE_SIGN_STYLE: Automatic
        ENABLE_HARDENED_RUNTIME: YES
    info:
      path: Sources/claude-bar/Info.plist
      properties:
        CFBundleDisplayName: claude-bar
        LSUIElement: YES
  claude-barTests:
    type: bundle.unit-test
    platform: macOS
    sources: Tests/claude-barTests
    dependencies:
      - target: claude-bar
    settings:
      base:
        SWIFT_VERSION: "6.0"
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/claude-bar.app/Contents/MacOS/claude-bar"
```

- [ ] **Step 3: Create source directories**

```bash
mkdir -p Sources/claude-bar Tests/claude-barTests/Fixtures
```

- [ ] **Step 4: Create placeholder `AppDelegate.swift`** (just enough to compile)

```swift
// Sources/claude-bar/AppDelegate.swift
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {}
}
```

- [ ] **Step 5: Generate Xcode project**

```bash
xcodegen generate
```

Expected: `claude-bar.xcodeproj` created with no errors.

- [ ] **Step 6: Verify the project builds**

```bash
xcodebuild -scheme claude-bar -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add project.yml Sources/ Tests/ claude-bar.xcodeproj
git commit -m "chore: scaffold xcode project with xcodegen"
```

---

## Task 2: UsageSnapshot Data Model

**Files:**
- Create: `Sources/claude-bar/UsageSnapshot.swift`

- [ ] **Step 1: Write `UsageSnapshot.swift`**

```swift
// Sources/claude-bar/UsageSnapshot.swift
struct UsageSnapshot: Sendable {
    let sessionPct: Int?
    let weekPct: Int?
    let weekResets: Date?
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme claude-bar -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/claude-bar/UsageSnapshot.swift
git commit -m "feat: add UsageSnapshot data model"
```

---

## Task 3: StatusFormatter (TDD)

**Files:**
- Create: `Sources/claude-bar/StatusFormatter.swift`
- Create: `Tests/claude-barTests/StatusFormatterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/claude-barTests/StatusFormatterTests.swift
import XCTest
@testable import claude_bar

final class StatusFormatterTests: XCTestCase {

    func testFullSnapshotDays() {
        let reset = Date(timeIntervalSinceNow: 5 * 24 * 3600 + 3600)
        let snap = UsageSnapshot(sessionPct: 19, weekPct: 89, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap), "19→89 [5d]")
    }

    func testFullSnapshotHours() {
        let reset = Date(timeIntervalSinceNow: 3 * 3600 + 60)
        let snap = UsageSnapshot(sessionPct: 5, weekPct: 20, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap), "5→20 [3h]")
    }

    func testFullSnapshotMinutes() {
        let reset = Date(timeIntervalSinceNow: 45 * 60)
        let snap = UsageSnapshot(sessionPct: 5, weekPct: 20, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap), "5→20 [45m]")
    }

    func testMissingSessionPct() {
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 89, weekResets: Date())
        XCTAssertEqual(StatusFormatter.format(snap), "--")
    }

    func testMissingWeekPct() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: nil, weekResets: Date())
        XCTAssertEqual(StatusFormatter.format(snap), "--")
    }

    func testMissingResetDate() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: 89, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap), "19→89 [--]")
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail (StatusFormatter doesn't exist yet)**

```bash
xcodebuild -scheme claude-bar -configuration Debug test 2>&1 | grep -E "FAIL|error:|BUILD FAILED" | head -10
```

Expected: `BUILD FAILED` — `StatusFormatter` not found.

- [ ] **Step 3: Write `StatusFormatter.swift`**

```swift
// Sources/claude-bar/StatusFormatter.swift
import Foundation

enum StatusFormatter {
    static func format(_ snapshot: UsageSnapshot) -> String {
        guard let sess = snapshot.sessionPct, let week = snapshot.weekPct else {
            return "--"
        }
        let timeStr = snapshot.weekResets.map { timeRemaining($0) } ?? "--"
        return "\(sess)→\(week) [\(timeStr)]"
    }

    private static func timeRemaining(_ date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "0m" }
        let hours = seconds / 3600
        if hours < 1 { return "\(Int(seconds / 60))m" }
        if hours < 24 { return "\(Int(hours))h" }
        return "\(Int(hours / 24))d"
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild -scheme claude-bar -configuration Debug test 2>&1 | grep -E "PASS|FAIL|Test Suite" | tail -10
```

Expected: All 6 tests pass. `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/claude-bar/StatusFormatter.swift Tests/claude-barTests/StatusFormatterTests.swift
git commit -m "feat: add StatusFormatter with unit tests"
```

---

## Task 4: UsageReader (TDD)

**Files:**
- Create: `Sources/claude-bar/UsageReader.swift`
- Create: `Tests/claude-barTests/UsageReaderTests.swift`
- Create: `Tests/claude-barTests/Fixtures/usage-cache.json`

- [ ] **Step 1: Write fixture file**

```json
{
  "fetched_at": "2026-05-01T20:58:21.000766+00:00",
  "session_pct": 19,
  "week_all_pct": 89,
  "session_resets": "2026-05-02T01:20:00.865645+00:00",
  "week_resets": "2026-05-06T20:59:59.865663+00:00"
}
```

Save to `Tests/claude-barTests/Fixtures/usage-cache.json`.

- [ ] **Step 2: Write failing tests**

```swift
// Tests/claude-barTests/UsageReaderTests.swift
import XCTest
@testable import claude_bar

final class UsageReaderTests: XCTestCase {

    private var fixtureURL: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/usage-cache.json")
    }

    func testReadValidCache() {
        let reader = UsageReader(cacheURL: fixtureURL)
        let snap = reader.read()
        XCTAssertEqual(snap.sessionPct, 19)
        XCTAssertEqual(snap.weekPct, 89)
        XCTAssertNotNil(snap.weekResets)
    }

    func testWeekResetsDate() throws {
        let reader = UsageReader(cacheURL: fixtureURL)
        let snap = reader.read()
        let resets = try XCTUnwrap(snap.weekResets)
        // 2026-05-06T20:59:59 UTC
        let cal = Calendar(identifier: .gregorian)
        var comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: resets)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 6)
        XCTAssertEqual(comps.hour, 20)
    }

    func testReadMissingFile() {
        let reader = UsageReader(cacheURL: URL(filePath: "/nonexistent/no.json"))
        let snap = reader.read()
        XCTAssertNil(snap.sessionPct)
        XCTAssertNil(snap.weekPct)
        XCTAssertNil(snap.weekResets)
    }

    func testReadCorruptJson() throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: "bad.json")
        try "not json {{{".write(to: tmp, atomically: true, encoding: .utf8)
        let reader = UsageReader(cacheURL: tmp)
        let snap = reader.read()
        XCTAssertNil(snap.sessionPct)
    }
}
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
xcodebuild -scheme claude-bar -configuration Debug test 2>&1 | grep -E "error:|BUILD FAILED" | head -5
```

Expected: `BUILD FAILED` — `UsageReader` not found.

- [ ] **Step 4: Write `UsageReader.swift`**

```swift
// Sources/claude-bar/UsageReader.swift
import Foundation

struct UsageReader: Sendable {
    let cacheURL: URL

    func read() -> UsageSnapshot {
        guard
            let data = try? Data(contentsOf: cacheURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return UsageSnapshot(sessionPct: nil, weekPct: nil, weekResets: nil)
        }

        let sessionPct = json["session_pct"] as? Int
        let weekPct = json["week_all_pct"] as? Int

        var weekResets: Date?
        if let str = json["week_resets"] as? String {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            weekResets = fmt.date(from: str)
        }

        return UsageSnapshot(sessionPct: sessionPct, weekPct: weekPct, weekResets: weekResets)
    }
}
```

- [ ] **Step 5: Run all tests to confirm they pass**

```bash
xcodebuild -scheme claude-bar -configuration Debug test 2>&1 | grep -E "Test Suite|PASS|FAIL" | tail -15
```

Expected: All 10 tests pass. `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Sources/claude-bar/UsageReader.swift Tests/claude-barTests/UsageReaderTests.swift Tests/claude-barTests/Fixtures/
git commit -m "feat: add UsageReader with unit tests"
```

---

## Task 5: AppDelegate, NSStatusItem, and Refresh Loop

**Files:**
- Modify: `Sources/claude-bar/AppDelegate.swift`

- [ ] **Step 1: Replace `AppDelegate.swift` with the full implementation**

```swift
// Sources/claude-bar/AppDelegate.swift
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var refreshLoop: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit claude-bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    // MARK: - Refresh

    private func startRefreshLoop() {
        refreshLoop?.cancel()
        refreshLoop = Task {
            while !Task.isCancelled {
                await updateTitle()
                try? await Task.sleep(for: .seconds(30))
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
            UsageReader(cacheURL: cacheURL).read()
        }.value
        statusItem.button?.title = StatusFormatter.format(snapshot)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme claude-bar -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run the app and verify it appears in the menu bar**

```bash
BUILD_DIR=$(xcodebuild -scheme claude-bar -configuration Debug -showBuildSettings 2>/dev/null \
  | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')
open "$BUILD_DIR/claude-bar.app"
```

Expected: A status item appears in the system menu bar showing a string like `2→19 [5d]`. Right-clicking shows "Quit claude-bar".

- [ ] **Step 4: Confirm tests still pass**

```bash
xcodebuild -scheme claude-bar -configuration Debug test 2>&1 | tail -3
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/claude-bar/AppDelegate.swift
git commit -m "feat: wire up NSStatusItem with 30s refresh loop and wake-from-sleep"
```

---

## Task 6: Release Build and Install Script

**Files:**
- Create: `scripts/install.sh`

- [ ] **Step 1: Create `scripts/install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="claude-bar"
DEST="/Applications/${APP_NAME}.app"

echo "Building release..."
xcodebuild -scheme "$APP_NAME" -configuration Release build \
  CONFIGURATION_BUILD_DIR="$(pwd)/build/Release" 2>&1 | tail -3

SRC="$(pwd)/build/Release/${APP_NAME}.app"

echo "Installing to ${DEST}..."
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo "Done. Launch with: open -a claude-bar"
echo "To add to Login Items: System Settings → General → Login Items → + → claude-bar"
```

- [ ] **Step 2: Make it executable and run it**

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Expected: `Done. Launch with: open -a claude-bar`

- [ ] **Step 3: Launch from Applications and verify the menu bar item appears**

```bash
open -a claude-bar
```

Expected: Status item visible in menu bar showing live data from `~/.claude/usage-cache.json`.

- [ ] **Step 4: Commit**

```bash
git add scripts/install.sh
git commit -m "chore: add release install script"
```
