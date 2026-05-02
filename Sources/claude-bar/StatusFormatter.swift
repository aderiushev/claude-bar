import Foundation

enum DisplayMode: String {
    case week, session

    var windowSeconds: TimeInterval {
        switch self {
        case .week:    return 7 * 24 * 3600
        case .session: return 24 * 3600
        }
    }
}

enum StatusFormatter {
    static func format(_ snapshot: UsageSnapshot, mode: DisplayMode = .week, now: Date = Date()) -> String {
        switch mode {
        case .week:
            guard let pct = snapshot.weekPct, let resets = snapshot.weekResets else { return "--" }
            return formatted(pct: pct, resets: resets, window: mode.windowSeconds, now: now)
        case .session:
            guard let pct = snapshot.sessionPct, let resets = snapshot.sessionResets else { return "--" }
            return formatted(pct: pct, resets: resets, window: mode.windowSeconds, now: now)
        }
    }

    private static func formatted(pct: Int, resets: Date, window: TimeInterval, now: Date) -> String {
        let timeStr = timeLabel(secondsUntil: resets.timeIntervalSince(now))
        let projected = projectedPct(current: pct, resets: resets, window: window, now: now)
        return "\(pct)→\(projected) [\(timeStr)]"
    }

    private static func projectedPct(current: Int, resets: Date, window: TimeInterval, now: Date) -> Int {
        let periodStart = resets.addingTimeInterval(-window)
        let elapsedHours = now.timeIntervalSince(periodStart) / 3600
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
