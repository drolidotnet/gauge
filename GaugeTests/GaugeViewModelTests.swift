import Foundation
import XCTest
@testable import Gauge

@MainActor
final class GaugeViewModelTests: XCTestCase {
    func testFailedRefreshKeepsCachedSnapshotAndMarksItStale() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaugeViewModelTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GaugeSnapshotStore(directoryURL: directory)
        let cached = GaugeSnapshot(
            currentScore: 41,
            currentRating: .fear,
            sourceUpdatedAt: Date(timeIntervalSince1970: 100),
            history: [],
            indicators: [],
            fetchedAt: Date(timeIntervalSince1970: 101)
        )
        try store.save(cached)

        let viewModel = GaugeViewModel(client: FailingGaugeFetcher(), store: store)
        await viewModel.load()

        XCTAssertEqual(viewModel.snapshot?.currentScore, 41)
        XCTAssertEqual(viewModel.snapshot?.isStale, true)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertFalse(viewModel.isInitialLoading)
    }

    func testSuccessfulFetchRemainsVisibleWhenCacheCannotBeWritten() async throws {
        let blockingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaugeBlockedStore-\(UUID().uuidString)")
        try Data("file-blocking-a-directory".utf8).write(to: blockingURL)
        defer { try? FileManager.default.removeItem(at: blockingURL) }

        let fresh = GaugeSnapshot(
            currentScore: 78,
            currentRating: .extremeGreed,
            sourceUpdatedAt: Date(timeIntervalSince1970: 200),
            history: [],
            indicators: [],
            fetchedAt: Date(timeIntervalSince1970: 201)
        )
        let viewModel = GaugeViewModel(
            client: SuccessfulGaugeFetcher(snapshot: fresh),
            store: GaugeSnapshotStore(directoryURL: blockingURL)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.snapshot, fresh)
        XCTAssertNil(viewModel.errorMessage)
    }
}

private struct FailingGaugeFetcher: GaugeDataFetching {
    func fetch() async throws -> GaugeSnapshot {
        throw URLError(.notConnectedToInternet)
    }
}

private struct SuccessfulGaugeFetcher: GaugeDataFetching {
    let snapshot: GaugeSnapshot

    func fetch() async throws -> GaugeSnapshot { snapshot }
}
