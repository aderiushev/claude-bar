// Sources/claude-bar/StatusFormatter.swift
import Foundation

enum StatusFormatter {
    static func format(_ snapshot: UsageSnapshot, now: Date = Date()) -> String {
        guard let sess = snapshot.sessionPct, let week = snapshot.weekPct else {
            return "--"
        }
        let timeStr = snapshot.weekResets.map { timeLabel(secondsUntil: $0.timeIntervalSince(now)) } ?? "--"
        return "\(sess)→\(week) [\(timeStr)]"
    }

    private static func timeLabel(secondsUntil seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0m" }
        let hours = seconds / 3600
        if hours < 1  { return "\(Int(seconds / 60))m" }
        if hours < 24 { return "\(Int(hours))h" }
        return "\(Int(hours / 24))d"
    }
}
