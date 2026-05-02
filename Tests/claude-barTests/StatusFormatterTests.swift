import XCTest
@testable import claude_bar

final class StatusFormatterTests: XCTestCase {
    private let anchor = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - Week mode (default)

    // 1 day elapsed of 7-day window, 10% used → rate=10/24 %/h → projects to 70% at end
    func testWeekLinearProjection() {
        let resets = anchor.addingTimeInterval(6 * 24 * 3600)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 10, sessionResets: nil, weekResets: resets)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "10→70 [6d]")
    }

    // Projection capped at 100%
    func testWeekProjectionCapsAt100() {
        let resets = anchor.addingTimeInterval(2 * 24 * 3600)   // 5 days elapsed, 2 remaining
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 80, sessionResets: nil, weekResets: resets)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "80→100 [2d]")
    }

    func testWeekMissingPct() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: nil, sessionResets: nil, weekResets: anchor)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "--")
    }

    func testWeekMissingResets() {
        let snap = UsageSnapshot(sessionPct: 19, weekPct: 22, sessionResets: nil, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "--")
    }

    func testWeekExpiredReset() {
        let resets = anchor.addingTimeInterval(-60)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 10, sessionResets: nil, weekResets: resets)
        XCTAssertEqual(StatusFormatter.format(snap, now: anchor), "10→10 [0m]")
    }

    // MARK: - Session mode

    // 6 hours elapsed of 24h window, 25% used → projects to 100%
    func testSessionLinearProjection() {
        let resets = anchor.addingTimeInterval(18 * 3600)   // 6h elapsed, 18h remaining
        let snap = UsageSnapshot(sessionPct: 25, weekPct: nil, sessionResets: resets, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, mode: .session, now: anchor), "25→100 [18h]")
    }

    // 12h elapsed of 24h window, 10% used → projects to 20%
    func testSessionProjection() {
        let resets = anchor.addingTimeInterval(12 * 3600)   // 12h elapsed, 12h remaining
        let snap = UsageSnapshot(sessionPct: 10, weekPct: nil, sessionResets: resets, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, mode: .session, now: anchor), "10→20 [12h]")
    }

    func testSessionMissingPct() {
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 50, sessionResets: anchor, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, mode: .session, now: anchor), "--")
    }

    func testSessionMissingResets() {
        let snap = UsageSnapshot(sessionPct: 30, weekPct: nil, sessionResets: nil, weekResets: nil)
        XCTAssertEqual(StatusFormatter.format(snap, mode: .session, now: anchor), "--")
    }

    // MARK: - Time labels

    func testTimeLabelDays() {
        let resets = anchor.addingTimeInterval(5 * 24 * 3600 + 3600)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 20, sessionResets: nil, weekResets: resets)
        XCTAssertTrue(StatusFormatter.format(snap, now: anchor).hasSuffix("[5d]"))
    }

    func testTimeLabelHours() {
        let resets = anchor.addingTimeInterval(3 * 3600 + 60)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 20, sessionResets: nil, weekResets: resets)
        XCTAssertTrue(StatusFormatter.format(snap, now: anchor).hasSuffix("[3h]"))
    }

    func testTimeLabelMinutes() {
        let resets = anchor.addingTimeInterval(45 * 60)
        let snap = UsageSnapshot(sessionPct: nil, weekPct: 20, sessionResets: nil, weekResets: resets)
        XCTAssertTrue(StatusFormatter.format(snap, now: anchor).hasSuffix("[45m]"))
    }
}
