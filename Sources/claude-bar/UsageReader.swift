import Foundation

enum UsageReader {
    static func read(from url: URL) throws -> UsageSnapshot {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let sessionPct = json["session_pct"] as? Int
        let weekPct    = json["week_all_pct"] as? Int

        var sessionResets: Date?
        if let raw = json["session_resets"] as? String {
            sessionResets = parseDate(raw)
        }

        var weekResets: Date?
        if let raw = json["week_resets"] as? String {
            weekResets = parseDate(raw)
        }

        return UsageSnapshot(
            sessionPct: sessionPct,
            weekPct: weekPct,
            sessionResets: sessionResets,
            weekResets: weekResets
        )
    }

    static func readOrEmpty(from url: URL) -> UsageSnapshot {
        (try? read(from: url)) ?? UsageSnapshot(sessionPct: nil, weekPct: nil, sessionResets: nil, weekResets: nil)
    }

    nonisolated(unsafe) private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        isoFull.date(from: string) ?? isoBasic.date(from: string)
    }
}
