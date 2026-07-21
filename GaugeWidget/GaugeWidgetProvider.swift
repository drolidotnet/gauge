import Foundation
import WidgetKit

struct GaugeWidgetIndicator: Sendable {
    let kind: GaugeIndicatorKind
    let score: Double?
    let rating: String?
    let isStale: Bool
}

struct GaugeWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let score: Double?
    let rating: String?
    let updatedAt: Date?
    let isStale: Bool
    let indicators: [GaugeWidgetIndicator]

    init(date: Date, snapshot: GaugeSnapshot?) {
        self.date = date

        guard let snapshot else {
            score = nil
            rating = nil
            updatedAt = nil
            isStale = false
            indicators = []
            return
        }

        score = snapshot.currentScore
        rating = snapshot.currentRating.displayName
        updatedAt = snapshot.sourceUpdatedAt
        isStale = snapshot.isStale
        indicators = snapshot.indicators.map { indicator in
            GaugeWidgetIndicator(
                kind: indicator.kind,
                score: indicator.score,
                rating: indicator.rating.displayName,
                isStale: indicator.isStale
            )
        }
    }

    init(
        date: Date,
        score: Double?,
        rating: String?,
        updatedAt: Date?,
        isStale: Bool,
        indicators: [GaugeWidgetIndicator]
    ) {
        self.date = date
        self.score = score
        self.rating = rating
        self.updatedAt = updatedAt
        self.isStale = isStale
        self.indicators = indicators
    }

    func indicator(for kind: GaugeIndicatorKind) -> GaugeWidgetIndicator? {
        indicators.first { $0.kind == kind }
    }

    static var preview: GaugeWidgetEntry {
        GaugeWidgetEntry(
            date: .now,
            score: 67,
            rating: "Greed",
            updatedAt: .now.addingTimeInterval(-8 * 60),
            isStale: false,
            indicators: [
                GaugeWidgetIndicator(kind: .marketMomentum, score: 74, rating: "Greed", isStale: false),
                GaugeWidgetIndicator(kind: .stockPriceStrength, score: 57, rating: "Neutral", isStale: false),
                GaugeWidgetIndicator(kind: .stockPriceBreadth, score: 63, rating: "Greed", isStale: false),
                GaugeWidgetIndicator(kind: .putCallOptions, score: 81, rating: "Extreme Greed", isStale: false),
                GaugeWidgetIndicator(kind: .marketVolatility, score: 69, rating: "Greed", isStale: false),
                GaugeWidgetIndicator(kind: .safeHavenDemand, score: 48, rating: "Neutral", isStale: false),
                GaugeWidgetIndicator(kind: .junkBondDemand, score: 72, rating: "Greed", isStale: false)
            ]
        )
    }

    static var unavailable: GaugeWidgetEntry {
        GaugeWidgetEntry(
            date: .now,
            score: nil,
            rating: nil,
            updatedAt: nil,
            isStale: false,
            indicators: []
        )
    }
}

struct GaugeWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = GaugeWidgetEntry
    typealias Intent = GaugeConfigurationIntent

    private let store: any GaugeSnapshotStoring
    private let fetcher: any GaugeDataFetching
    private let now: () -> Date

    init(
        store: any GaugeSnapshotStoring = GaugeSnapshotStore(),
        fetcher: any GaugeDataFetching = CNNFearGreedClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.fetcher = fetcher
        self.now = now
    }

    func placeholder(in context: Context) -> GaugeWidgetEntry {
        .preview
    }

    func snapshot(
        for configuration: GaugeConfigurationIntent,
        in context: Context
    ) async -> GaugeWidgetEntry {
        guard !context.isPreview else { return .preview }

        let currentDate = now()
        guard let cached = try? store.load() else {
            return GaugeWidgetEntry(date: currentDate, snapshot: nil)
        }

        let snapshot = GaugeRefreshPolicy.isFresh(cached, now: currentDate)
            ? cached
            : cached.markingStale()
        return GaugeWidgetEntry(date: currentDate, snapshot: snapshot)
    }

    func timeline(
        for configuration: GaugeConfigurationIntent,
        in context: Context
    ) async -> Timeline<GaugeWidgetEntry> {
        let currentDate = now()
        let resolution = await GaugeTimelineResolver.resolve(
            store: store,
            fetcher: fetcher,
            now: currentDate
        )
        let entry = GaugeWidgetEntry(date: currentDate, snapshot: resolution.snapshot)
        return Timeline(entries: [entry], policy: .after(resolution.nextRefreshDate))
    }
}
