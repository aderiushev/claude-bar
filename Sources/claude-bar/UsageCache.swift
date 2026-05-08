import Foundation

enum UsageCache {
    static let bundleSubdir = "com.aderiushev.claude-bar"
    static let filename = "usage-cache.json"

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return support.appending(path: bundleSubdir).appending(path: filename)
    }

    static func read() -> UsageSnapshot {
        UsageReader.readOrEmpty(from: fileURL)
    }

    static func fetchedAt() -> Date? {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["fetched_at"] as? String else { return nil }
        return parseDate(raw)
    }

    static func write(_ snapshot: UsageSnapshot, orgUUID: String?, fetchedAt: Date = Date()) throws {
        let url = fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        var dict: [String: Any] = [
            "fetched_at": isoFormatter.string(from: fetchedAt),
        ]
        if let v = orgUUID            { dict["org_uuid"] = v }
        if let v = snapshot.sessionPct { dict["session_pct"] = v }
        if let v = snapshot.weekPct    { dict["week_all_pct"] = v }
        if let v = snapshot.sessionResets { dict["session_resets"] = isoFormatter.string(from: v) }
        if let v = snapshot.weekResets    { dict["week_resets"] = isoFormatter.string(from: v) }

        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        try data.write(to: url, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ s: String) -> Date? {
        isoFormatter.date(from: s) ?? isoBasic.date(from: s)
    }
}
