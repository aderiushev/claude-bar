import XCTest
@testable import claude_bar

final class StatusFormatterTests: XCTestCase {
    private let anchor = Date(timeIntervalSinceReferenceDate: 0)

    // 1 day elapsed of 7-day window, 10% used → rate=10/24 %/h → projects to 70% at end
    func testLinearProjection() {
        let resets = anchor.addingTimeInterval(6 * 24 * 3600)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 10, weekResets: resets)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "10→70 [6d]")
    }

    // Projection capped at 100%
    func testProjectionCapsAt100() {
        let resets = anchor.addingTimeInterval(2 * 24 * 3600)   // 5 days elapsed, 2 remaining
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 80, weekResets: resets)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "80→100 [2d]")
    }

    // Time label: days
    func testTimeLabelDays() {
        let resets = anchor.addingTimeInterval(5 * 24 * 3600 + 3600)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 20, weekResets: resets)
        XCTAssertTrue(StatusFormatter.format(snap, now: anchor).hasSuffix("[5d]"))
    }

    // Time label: hours
    func testTimeLabelHours() {
        let resets = anchor.addingTimeInterval(3 * 3600 + 60)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 20, weekResets: resets)
        XCTAssertTrue(StatusFormatter.format(snap, now: anchor).hasSuffix("[3h]"))
    }

    // Time label: minutes
    func testTimeLabelMinutes() {
        let resets = anchor.addingTimeInterval(45 * 60)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 20, weekResets: resets)
        XCTAssertTrue(StatusFormatter.format(snap, now: anchor).hasSuffix("[45m]"))
    }

    // Missing weekPct → --
    func testMissingWeekPct() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: nil, weekResets: anchor)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "--")
    }

    // Missing weekResets → --
    func testMissingResetDate() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: 22, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "--")
    }

    // Reset already passed → projection stays at current, time shows 0m
    func testExpiredReset() {
        let resets = anchor.addingTimeInterval(-60)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 10, weekResets: resets)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "10→10 [0m]")
    }
}
