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
        comps.timeZone = TimeZone(identifier: "UTC")
        let expected = cal.date(from: comps)!
        XCTAssertEqual(snapshot.weekResets!.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testMissingFileReturnsEmptySnapshot() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-usage-cache.json")
        let snapshot = UsageReader.readOrEmpty(from: missing)
        XCTAssertNil(snapshot.sessionPct)
        XCTAssertNil(snapshot.weekPct)
        XCTAssertNil(snapshot.weekResets)
    }
}
