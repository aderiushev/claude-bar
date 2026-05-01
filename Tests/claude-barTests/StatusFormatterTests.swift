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
