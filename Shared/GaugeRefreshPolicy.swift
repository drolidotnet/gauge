import Foundation

/// Widget/app refresh timings kept pure so timeline behavior is deterministic
/// in tests. WidgetKit may schedule later than these requested dates.
public enum GaugeRefreshPolicy {
    public static let freshCacheInterval: TimeInterval = 15 * 60
    public static let successRefreshInterval: TimeInterval = 12 * 60 * 60
    public static let failureRetryInterval: TimeInterval = 60 * 60

    public static func isFresh(_ snapshot: GaugeSnapshot, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        return age >= 0 && age <= freshCacheInterval
    }

    public static func nextRefresh(afterSuccessAt date: Date) -> Date {
        date.addingTimeInterval(successRefreshInterval)
    }

    public static func nextRetry(afterFailureAt date: Date) -> Date {
        date.addingTimeInterval(failureRetryInterval)
    }
}
