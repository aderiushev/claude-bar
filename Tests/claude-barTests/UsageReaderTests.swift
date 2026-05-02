import XCTest
@testable import claude_bar

final class UsageReaderTests: XCTestCase {
    private var fixtureURL: URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/usage-cache.json")
    }

    func testReadsSessionAndWeekPct() throws {
        let snapshot = try UsageReader.read(from: fixtureURL)
        XCTAssertEqual(snapshot.sessionPct, 19)
        XCTAssertEqual(snapshot.weekPct, 89)
    }

    func testReadsWeekResets() throws {
        let snapshot = try UsageReader.read(from: fixtureURL)
        XCTAssertNotNil(snapshot.weekResets)
        // 2026-05-06T20:59:59.865663+00:00
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 6
        comps.hour = 20; comps.minute = 59; comps.second = 59
        comps.nanosecond = 865_663_000
        comps.timeZone = TimeZone(identifier: "UTC")
        let expected = cal.date(from: comps)!
        XCTAssertEqual(snapshot.weekResets!.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testReadsSessionResets() throws {
        let snapshot = try UsageReader.read(from: fixtureURL)
        XCTAssertNotNil(snapshot.sessionResets)
        // 2026-05-02T01:20:00.865645+00:00
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 2
        comps.hour = 1; comps.minute = 20; comps.second = 0
        comps.nanosecond = 865_645_000
        comps.timeZone = TimeZone(identifier: "UTC")
        let expected = cal.date(from: comps)!
        XCTAssertEqual(snapshot.sessionResets!.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testMissingFileReturnsEmptySnapshot() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-usage-cache.json")
        let snapshot = UsageReader.readOrEmpty(from: missing)
        XCTAssertNil(snapshot.sessionPct)
        XCTAssertNil(snapshot.weekPct)
        XCTAssertNil(snapshot.sessionResets)
        XCTAssertNil(snapshot.weekResets)
    }
}
