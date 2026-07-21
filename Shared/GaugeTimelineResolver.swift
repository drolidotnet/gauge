import Foundation

public protocol GaugeSnapshotStoring: Sendable {
    func load() throws -> GaugeSnapshot?

    @discardableResult
    func save(_ snapshot: GaugeSnapshot) throws -> Bool
}

extension GaugeSnapshotStore: GaugeSnapshotStoring {}

public struct GaugeTimelineResolution: Sendable {
    public enum Source: Sendable, Equatable {
        case freshCache
        case fetched
        case staleCache
        case unavailable
    }

    public let snapshot: GaugeSnapshot?
    public let nextRefreshDate: Date
    public let source: Source

    public init(
        snapshot: GaugeSnapshot?,
        nextRefreshDate: Date,
        source: Source
    ) {
        self.snapshot = snapshot
        self.nextRefreshDate = nextRefreshDate
        self.source = source
    }
}

/// Pure WidgetKit-independent timeline loading, shared so cache/fetch/fallback
/// behavior can be exercised by the app-hosted unit-test target.
public enum GaugeTimelineResolver {
    public static func resolve(
        store: any GaugeSnapshotStoring,
        fetcher: any GaugeDataFetching,
        now: Date
    ) async -> GaugeTimelineResolution {
        let cached = try? store.load()

        if let cached, GaugeRefreshPolicy.isFresh(cached, now: now) {
            return GaugeTimelineResolution(
                snapshot: cached,
                nextRefreshDate: GaugeRefreshPolicy.nextRefresh(afterSuccessAt: now),
                source: .freshCache
            )
        }

        do {
            let fetched = try await fetcher.fetch()
            let merged = fetched.mergingMissingIndicators(from: cached)
            let displayedSnapshot: GaugeSnapshot
            do {
                let didSave = try store.save(merged)
                displayedSnapshot = didSave
                    ? merged
                    : ((try? store.load()) ?? merged)
            } catch {
                // A valid response remains usable even when persistence fails.
                displayedSnapshot = merged
            }

            return GaugeTimelineResolution(
                snapshot: displayedSnapshot,
                nextRefreshDate: GaugeRefreshPolicy.nextRefresh(afterSuccessAt: now),
                source: .fetched
            )
        } catch {
            let fallback = cached?.markingStale()
            return GaugeTimelineResolution(
                snapshot: fallback,
                nextRefreshDate: GaugeRefreshPolicy.nextRetry(afterFailureAt: now),
                source: fallback == nil ? .unavailable : .staleCache
            )
        }
    }
}
