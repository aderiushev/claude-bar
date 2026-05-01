// Tests/claude-barTests/StatusFormatterTests.swift
import XCTest
@testable import claude_bar

final class StatusFormatterTests: XCTestCase {
    private let anchor = Date(timeIntervalSinceReferenceDate: 0) // fixed "now"

    func testFullSnapshotDays() {
        let reset = anchor.addingTimeInterval(5 * 24 * 3600 + 3600)
        let snap = UsageSnapshot(sessionPct: 19, weekPct: 89, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "19→89 [5d]")
    }

    func testFullSnapshotHours() {
        let reset = anchor.addingTimeInterval(3 * 3600 + 60)
        let snap = UsageSnapshot(sessionPct: 5, weekPct: 20, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "5→20 [3h]")
    }

    func testFullSnapshotMinutes() {
        let reset = anchor.addingTimeInterval(45 * 60)
        let snap = UsageSnapshot(sessionPct: 5, weekPct: 20, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "5→20 [45m]")
    }

    func testMissingSessionPct() {
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 89, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "--")
    }

    func testMissingWeekPct() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: nil, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "--")
    }

    func testMissingResetDate() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: 89, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "19→89 [--]")
    }

    func testExpiredReset() {
        let reset = anchor.addingTimeInterval(-60) // 60 seconds in the past
        let snap = UsageSnapshot(sessionPct: 10, weekPct: 50, weekResets: reset)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "10→50 [0m]")
    }
}
