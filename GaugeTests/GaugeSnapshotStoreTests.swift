import Foundation
import XCTest
@testable import Gauge

final class GaugeSnapshotStoreTests: XCTestCase {
    private var directoryURL: URL!
    private var store: GaugeSnapshotStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaugeTests-\(UUID().uuidString)", isDirectory: true)
        store = GaugeSnapshotStore(directoryURL: directoryURL)
    }

    override func tearDownWithError() throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        store = nil
        directoryURL = nil
        try super.tearDownWithError()
    }

    func testRoundTripsFullSnapshotWithNineSeries() throws {
        let snapshot = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 200))

        XCTAssertTrue(try store.save(snapshot))
        XCTAssertEqual(try store.load(), snapshot)
        XCTAssertEqual(try store.load()?.indicators.flatMap(\.series).count, 9)
    }

    func testNewerFetchTimestampWins() throws {
        let newest = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 300), score: 80)
        let older = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 200), score: 10)
        let later = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 400), score: 55)

        XCTAssertTrue(try store.save(newest))
        XCTAssertFalse(try store.save(older))
        XCTAssertEqual(try store.load()?.currentScore, 80)
        XCTAssertTrue(try store.save(later))
        XCTAssertEqual(try store.load()?.currentScore, 55)
    }

    func testSavingRepairsCorruptCache() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(
            to: directoryURL.appendingPathComponent(GaugeSnapshotStore.defaultFileName)
        )

        let snapshot = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 500))
        XCTAssertTrue(try store.save(snapshot))
        XCTAssertEqual(try store.load(), snapshot)
    }

    func testConcurrentStoreInstancesCannotOverwriteNewerSnapshot() throws {
        let directory = try XCTUnwrap(directoryURL)
        let snapshots = (1...24).map { value in
            makeSnapshot(
                fetchedAt: Date(timeIntervalSince1970: Double(value)),
                score: Double(value)
            )
        }

        DispatchQueue.concurrentPerform(iterations: snapshots.count) { index in
            let independentStore = GaugeSnapshotStore(directoryURL: directory)
            _ = try? independentStore.save(snapshots[index])
        }

        XCTAssertEqual(try store.load()?.fetchedAt, snapshots.last?.fetchedAt)
        XCTAssertEqual(try store.load()?.currentScore, 24)
    }

    func testRefreshPolicyUsesFifteenMinutesTwelveHoursAndOneHour() {
        let now = Date(timeIntervalSince1970: 10_000)
        let fresh = makeSnapshot(fetchedAt: now.addingTimeInterval(-(15 * 60)))
        let expired = makeSnapshot(fetchedAt: now.addingTimeInterval(-(15 * 60) - 0.001))

        XCTAssertTrue(GaugeRefreshPolicy.isFresh(fresh, now: now))
        XCTAssertFalse(GaugeRefreshPolicy.isFresh(expired, now: now))
        XCTAssertEqual(
            GaugeRefreshPolicy.nextRefresh(afterSuccessAt: now),
            now.addingTimeInterval(12 * 60 * 60)
        )
        XCTAssertEqual(
            GaugeRefreshPolicy.nextRetry(afterFailureAt: now),
            now.addingTimeInterval(60 * 60)
        )
    }

    private func makeSnapshot(
        fetchedAt: Date,
        score: Double = 49.4
    ) -> GaugeSnapshot {
        let point = GaugePoint(timestamp: fetchedAt.addingTimeInterval(-60), value: 1)
        let seriesForKind: (GaugeIndicatorKind) -> [GaugeSeries] = { kind in
            kind.expectedSeriesIDs.map {
                GaugeSeries(
                    id: $0,
                    displayName: $0,
                    valueFormat: kind.valueFormat,
                    points: [point]
                )
            }
        }
        let indicators = GaugeIndicatorKind.allCases.map { kind in
            GaugeIndicator(
                kind: kind,
                score: score,
                rating: FearGreedRating(score: score),
                sourceUpdatedAt: fetchedAt,
                series: seriesForKind(kind)
            )
        }

        return GaugeSnapshot(
            currentScore: score,
            currentRating: FearGreedRating(score: score),
            sourceUpdatedAt: fetchedAt,
            history: [
                GaugeHistoryPoint(
                    timestamp: fetchedAt.addingTimeInterval(-60),
                    score: score,
                    rating: FearGreedRating(score: score)
                ),
            ],
            indicators: indicators,
            fetchedAt: fetchedAt
        )
    }
}
