import Combine
import Foundation
import WidgetKit

@MainActor
final class GaugeViewModel: ObservableObject {
    @Published private(set) var snapshot: GaugeSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isInitialLoading = true
    @Published private(set) var errorMessage: String?

    private let client: any GaugeDataFetching
    private let store: GaugeSnapshotStore
    private var hasLoaded = false

    init(
        client: any GaugeDataFetching = CNNFearGreedClient(),
        store: GaugeSnapshotStore = GaugeSnapshotStore()
    ) {
        self.client = client
        self.store = store
    }

    private init(previewSnapshot: GaugeSnapshot) {
        client = PreviewGaugeClient(snapshot: previewSnapshot)
        store = GaugeSnapshotStore(directoryURL: FileManager.default.temporaryDirectory)
        snapshot = previewSnapshot
        hasLoaded = true
        isInitialLoading = false
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        do {
            snapshot = try store.load()
        } catch {
            errorMessage = "Saved data could not be read."
        }

        isInitialLoading = false
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        let cachedSnapshot = snapshot ?? (try? store.load())

        let fetchedSnapshot: GaugeSnapshot
        do {
            fetchedSnapshot = try await client.fetch()
        } catch is CancellationError {
            return
        } catch {
            if let cachedSnapshot {
                snapshot = cachedSnapshot.markingStale()
            }
            errorMessage = Self.message(for: error)
            return
        }

        let mergedSnapshot = fetchedSnapshot.mergingMissingIndicators(from: cachedSnapshot)
        do {
            let didSave = try store.save(mergedSnapshot)
            snapshot = didSave ? mergedSnapshot : ((try? store.load()) ?? mergedSnapshot)
        } catch {
            // Persistence failure must not hide a valid, freshly fetched index.
            snapshot = mergedSnapshot
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "GaugeWidget")
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return "The latest market data could not be loaded. Please try again."
    }
}

private struct PreviewGaugeClient: GaugeDataFetching {
    let snapshot: GaugeSnapshot

    func fetch() async throws -> GaugeSnapshot { snapshot }
}

extension GaugeViewModel {
    static var preview: GaugeViewModel {
        let now = Date.now
        let points: (_ base: Double, _ swing: Double) -> [GaugePoint] = { base, swing in
            (0..<370).compactMap { offset in
                guard let date = Calendar.current.date(byAdding: .day, value: offset - 369, to: now) else {
                    return nil
                }
                let wave = sin(Double(offset) / 17) * swing
                let drift = Double(offset) / 370 * swing * 0.6
                return GaugePoint(timestamp: date, value: base + wave + drift)
            }
        }

        let indicators: [GaugeIndicator] = [
            GaugeIndicator(
                kind: .marketMomentum,
                score: 71.8,
                rating: .greed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [
                    GaugeSeries(id: "market_momentum_sp500", displayName: "S&P 500", valueFormat: .index, points: points(5_450, 180)),
                    GaugeSeries(id: "market_momentum_sp125", displayName: "125-day average", valueFormat: .index, points: points(5_280, 45))
                ]
            ),
            GaugeIndicator(
                kind: .stockPriceStrength,
                score: 63.2,
                rating: .greed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [GaugeSeries(id: "stock_price_strength", displayName: "Net highs", valueFormat: .percentagePoints, points: points(2.1, 3.8))]
            ),
            GaugeIndicator(
                kind: .stockPriceBreadth,
                score: 57.4,
                rating: .greed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [GaugeSeries(id: "stock_price_breadth", displayName: "Summation index", valueFormat: .index, points: points(320, 850))]
            ),
            GaugeIndicator(
                kind: .putCallOptions,
                score: 43.2,
                rating: .fear,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [GaugeSeries(id: "put_call_options", displayName: "Put/call ratio", valueFormat: .ratio, points: points(0.82, 0.18))]
            ),
            GaugeIndicator(
                kind: .marketVolatility,
                score: 68.7,
                rating: .greed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [
                    GaugeSeries(id: "market_volatility_vix", displayName: "VIX", valueFormat: .decimal, points: points(16, 4.5)),
                    GaugeSeries(id: "market_volatility_vix_50", displayName: "50-day average", valueFormat: .decimal, points: points(18, 1.3))
                ]
            ),
            GaugeIndicator(
                kind: .safeHavenDemand,
                score: 75.1,
                rating: .extremeGreed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [GaugeSeries(id: "safe_haven_demand", displayName: "Return difference", valueFormat: .percentagePoints, points: points(1.4, 4.2))]
            ),
            GaugeIndicator(
                kind: .junkBondDemand,
                score: 70.5,
                rating: .greed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                series: [GaugeSeries(id: "junk_bond_demand", displayName: "Yield spread", valueFormat: .percentagePoints, points: points(3.1, 0.5))]
            )
        ]

        let history = (0..<370).compactMap { offset -> GaugeHistoryPoint? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset - 369, to: now) else {
                return nil
            }
            let score = min(100, max(0, 55 + sin(Double(offset) / 20) * 20 + Double(offset) / 30))
            return GaugeHistoryPoint(timestamp: date, score: score, rating: FearGreedRating(score: score))
        }

        return GaugeViewModel(
            previewSnapshot: GaugeSnapshot(
                currentScore: 72,
                currentRating: .greed,
                sourceUpdatedAt: now.addingTimeInterval(-720),
                history: history,
                indicators: indicators,
                fetchedAt: now.addingTimeInterval(-600),
                isStale: false
            )
        )
    }
}
