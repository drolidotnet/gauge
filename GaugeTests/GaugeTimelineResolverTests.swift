import Foundation
import XCTest
@testable import Gauge

final class GaugeTimelineResolverTests: XCTestCase {
    func testFreshCacheBypassesFetchAndRequestsTwelveHourRefresh() async {
        let now = Date(timeIntervalSince1970: 100_000)
        let cached = makeSnapshot(score: 44, fetchedAt: now.addingTimeInterval(-10 * 60))
        let store = TimelineTestStore(snapshot: cached)
        let fetcher = TimelineTestFetcher(outcome: .failure)

        let result = await GaugeTimelineResolver.resolve(
            store: store,
            fetcher: fetcher,
            now: now
        )

        XCTAssertEqual(result.source, .freshCache)
        XCTAssertEqual(result.snapshot, cached)
        XCTAssertEqual(result.nextRefreshDate, now.addingTimeInterval(12 * 60 * 60))
        let fetchCount = await fetcher.count
        XCTAssertEqual(fetchCount, 0)
    }

    func testExpiredCacheFetchesSavesAndRequestsTwelveHourRefresh() async {
        let now = Date(timeIntervalSince1970: 100_000)
        let fetched = makeSnapshot(score: 71, fetchedAt: now)
        let store = TimelineTestStore(snapshot: nil)
        let fetcher = TimelineTestFetcher(outcome: .success(fetched))

        let result = await GaugeTimelineResolver.resolve(
            store: store,
            fetcher: fetcher,
            now: now
        )

        XCTAssertEqual(result.source, .fetched)
        XCTAssertEqual(result.snapshot, fetched)
        XCTAssertEqual(store.snapshot, fetched)
        XCTAssertEqual(result.nextRefreshDate, now.addingTimeInterval(12 * 60 * 60))
        let fetchCount = await fetcher.count
        XCTAssertEqual(fetchCount, 1)
    }

    func testConcurrentNewerCacheWinsOverOlderCompletedFetch() async {
        let now = Date(timeIntervalSince1970: 100_000)
        let newerCache = makeSnapshot(score: 88, fetchedAt: now.addingTimeInterval(-1_000))
        let olderFetch = makeSnapshot(score: 12, fetchedAt: now.addingTimeInterval(-1_100))
        let store = TimelineTestStore(snapshot: newerCache)
        let fetcher = TimelineTestFetcher(outcome: .success(olderFetch))

        let result = await GaugeTimelineResolver.resolve(
            store: store,
            fetcher: fetcher,
            now: now
        )

        XCTAssertEqual(result.source, .fetched)
        XCTAssertEqual(result.snapshot?.currentScore, 88)
        XCTAssertEqual(store.snapshot?.currentScore, 88)
    }

    func testFailureMarksExpiredCacheStaleAndRequestsOneHourRetry() async {
        let now = Date(timeIntervalSince1970: 100_000)
        let cached = makeSnapshot(score: 36, fetchedAt: now.addingTimeInterval(-2_000))
        let store = TimelineTestStore(snapshot: cached)
        let fetcher = TimelineTestFetcher(outcome: .failure)

        let result = await GaugeTimelineResolver.resolve(
            store: store,
            fetcher: fetcher,
            now: now
        )

        XCTAssertEqual(result.source, .staleCache)
        XCTAssertEqual(result.snapshot?.currentScore, 36)
        XCTAssertEqual(result.snapshot?.isStale, true)
        XCTAssertEqual(result.nextRefreshDate, now.addingTimeInterval(60 * 60))
    }

    func testFailureWithoutCacheIsUnavailableAndNeverBecomesZero() async {
        let now = Date(timeIntervalSince1970: 100_000)
        let result = await GaugeTimelineResolver.resolve(
            store: TimelineTestStore(snapshot: nil),
            fetcher: TimelineTestFetcher(outcome: .failure),
            now: now
        )

        XCTAssertEqual(result.source, .unavailable)
        XCTAssertNil(result.snapshot)
        XCTAssertEqual(result.nextRefreshDate, now.addingTimeInterval(60 * 60))
    }

    private func makeSnapshot(score: Double, fetchedAt: Date) -> GaugeSnapshot {
        GaugeSnapshot(
            currentScore: score,
            currentRating: FearGreedRating(score: score),
            sourceUpdatedAt: fetchedAt,
            history: [],
            indicators: [],
            fetchedAt: fetchedAt
        )
    }
}

private final class TimelineTestStore: GaugeSnapshotStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSnapshot: GaugeSnapshot?

    init(snapshot: GaugeSnapshot?) {
        storedSnapshot = snapshot
    }

    var snapshot: GaugeSnapshot? {
        lock.withLock { storedSnapshot }
    }

    func load() throws -> GaugeSnapshot? {
        lock.withLock { storedSnapshot }
    }

    func save(_ snapshot: GaugeSnapshot) throws -> Bool {
        lock.withLock {
            if let storedSnapshot, storedSnapshot.fetchedAt >= snapshot.fetchedAt {
                return false
            }
            storedSnapshot = snapshot
            return true
        }
    }
}

private actor TimelineTestFetcher: GaugeDataFetching {
    enum Outcome: Sendable {
        case success(GaugeSnapshot)
        case failure
    }

    let outcome: Outcome
    private(set) var count = 0

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func fetch() async throws -> GaugeSnapshot {
        count += 1
        switch outcome {
        case let .success(snapshot):
            return snapshot
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }
}
