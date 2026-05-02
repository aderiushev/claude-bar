import Foundation

enum StatusFormatter {
    static func format(_ snapshot: UsageSnapshot, now: Date = Date()) -> String {
        guard let week = snapshot.weekPct, let resets = snapshot.weekResets else {
            return "--"
        }
        let timeStr = timeLabel(secondsUntil: resets.timeIntervalSince(now))
        let projected = projectedPct(current: week, resets: resets, now: now)
        return "\(week)→\(projected) [\(timeStr)]"
    }

    private static func projectedPct(current: Int, resets: Date, now: Date) -> Int {
        let weekStart = resets.addingTimeInterval(-7 * 24 * 3600)
        let elapsedHours = now.timeIntervalSince(weekStart) / 3600
        let remainingHours = max(resets.timeIntervalSince(now) / 3600, 0)
        guard elapsedHours > 0.5 else { return current }
        let rate = Double(current) / elapsedHours
        return min(Int(Double(current) + rate * remainingHours), 100)
    }

    private static func timeLabel(secondsUntil seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0m" }
        let hours = seconds / 3600
        if hours < 1  { return "\(Int(seconds / 60))m" }
        if hours < 24 { return "\(Int(hours))h" }
        return "\(Int(hours / 24))d"
    }
}
