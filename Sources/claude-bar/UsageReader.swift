import Foundation

enum UsageReader {
    static func read(from url: URL) throws -> UsageSnapshot {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let sessionPct = json["session_pct"] as? Int
        let weekPct    = json["week_all_pct"] as? Int

        var weekResets: Date?
        if let raw = json["week_resets"] as? String {
            weekResets = parseDate(raw)
        }

        return UsageSnapshot(sessionPct: sessionPct, weekPct: weekPct, weekResets: weekResets)
    }

    static func readOrEmpty(from url: URL) -> UsageSnapshot {
        (try? read(from: url)) ?? UsageSnapshot(sessionPct: nil, weekPct: nil, weekResets: nil)
    }

    private static func parseDate(_ string: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: string) { return date }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: string)
    }
}
