import Foundation

struct UsageSnapshot: Sendable {
    let sessionPct: Int?
    let weekPct: Int?
    let sessionResets: Date?
    let weekResets: Date?
}
