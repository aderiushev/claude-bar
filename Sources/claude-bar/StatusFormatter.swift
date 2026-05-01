// Sources/claude-bar/StatusFormatter.swift
import Foundation

enum StatusFormatter {
    static func format(_ snapshot: UsageSnapshot) -> String {
        guard let sess = snapshot.sessionPct, let week = snapshot.weekPct else {
            return "--"
        }
        let timeStr = snapshot.weekResets.map { timeRemaining($0) } ?? "--"
        return "\(sess)→\(week) [\(timeStr)]"
    }

    private static func timeRemaining(_ date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "0m" }
        let hours = seconds / 3600
        if hours < 1 { return "\(Int((seconds / 60).rounded()))m" }
        if hours < 24 { return "\(Int(hours))h" }
        return "\(Int(hours / 24))d"
    }
}
