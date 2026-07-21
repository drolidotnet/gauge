import XCTest
@testable import Gauge

final class GaugeModelsTests: XCTestCase {
    func testRatingBoundariesMatchCNNBands() {
        let cases: [(Double, FearGreedRating)] = [
            (0, .extremeFear),
            (25, .extremeFear),
            (25.001, .fear),
            (44.999, .fear),
            (45, .neutral),
            (55, .neutral),
            (55.001, .greed),
            (74.999, .greed),
            (75, .extremeGreed),
            (100, .extremeGreed),
        ]

        for (score, expected) in cases {
            XCTAssertEqual(FearGreedRating(score: score), expected, "score \(score)")
        }
    }

    func testRatingNormalizationFallsBackForUnknownValues() {
        XCTAssertEqual(
            FearGreedRating.normalized("  EXTREME_GREED ", fallbackScore: 0),
            .extremeGreed
        )
        XCTAssertEqual(
            FearGreedRating.normalized("unexpected", fallbackScore: 40),
            .fear
        )
    }

    func testValueFormatsPreserveMetricUnits() {
        XCTAssertEqual(GaugeValueFormat.ratio.format(0.7209), "0.72")
        XCTAssertEqual(GaugeValueFormat.percentagePoints.format(3.038), "3.04 pp")
        XCTAssertEqual(GaugeValueFormat.index.format(7_575.39), "7,575.39")
        XCTAssertEqual(GaugeValueFormat.index.format(7_575.39, compact: true), "7.6K")
        XCTAssertEqual(GaugeValueFormat.decimal.format(16.129), "16.13")
    }

    func testSnapshotOrdersIndicatorsInCanonicalCNNOrder() {
        let snapshot = makeSnapshot(indicators: [
            makeIndicator(.junkBondDemand),
            makeIndicator(.marketMomentum),
            makeIndicator(.putCallOptions),
        ])

        XCTAssertEqual(
            snapshot.indicators.map(\.kind),
            [.marketMomentum, .putCallOptions, .junkBondDemand]
        )
    }

    func testMergeReusesMissingIndicatorAndMarksItStale() {
        let cached = makeSnapshot(indicators: [makeIndicator(.marketMomentum)])
        let fresh = makeSnapshot(indicators: [])

        let merged = fresh.mergingMissingIndicators(from: cached)

        XCTAssertFalse(merged.isStale)
        XCTAssertEqual(merged.indicators.count, 1)
        XCTAssertEqual(merged.indicators.first?.kind, .marketMomentum)
        XCTAssertEqual(merged.indicators.first?.isStale, true)
    }

    func testMergeRestoresOnlyMissingPairedSeries() {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let cached = makeSnapshot(indicators: [
            GaugeIndicator(
                kind: .marketVolatility,
                score: 30,
                rating: .fear,
                sourceUpdatedAt: oldDate,
                series: [
                    GaugeSeries(
                        id: "market_volatility_vix",
                        displayName: "VIX",
                        valueFormat: .decimal,
                        points: [GaugePoint(timestamp: oldDate, value: 18)]
                    ),
                    GaugeSeries(
                        id: "market_volatility_vix_50",
                        displayName: "50-day average",
                        valueFormat: .decimal,
                        points: [GaugePoint(timestamp: oldDate, value: 20)]
                    ),
                ]
            ),
        ])
        let fresh = makeSnapshot(indicators: [
            GaugeIndicator(
                kind: .marketVolatility,
                score: 50,
                rating: .neutral,
                sourceUpdatedAt: newDate,
                series: [
                    GaugeSeries(
                        id: "market_volatility_vix",
                        displayName: "VIX",
                        valueFormat: .decimal,
                        points: [GaugePoint(timestamp: newDate, value: 16)]
                    ),
                ]
            ),
        ])

        let merged = fresh.mergingMissingIndicators(from: cached)
        let indicator = merged.indicator(for: .marketVolatility)

        XCTAssertEqual(indicator?.score, 50)
        XCTAssertEqual(indicator?.series.count, 2)
        XCTAssertEqual(indicator?.series[0].points.first?.value, 16)
        XCTAssertEqual(indicator?.series[1].points.first?.value, 20)
        XCTAssertEqual(indicator?.isStale, true)
    }

    private func makeSnapshot(indicators: [GaugeIndicator]) -> GaugeSnapshot {
        GaugeSnapshot(
            currentScore: 49.49,
            currentRating: .neutral,
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_000),
            history: [],
            indicators: indicators,
            fetchedAt: Date(timeIntervalSince1970: 1_001)
        )
    }

    private func makeIndicator(_ kind: GaugeIndicatorKind) -> GaugeIndicator {
        GaugeIndicator(
            kind: kind,
            score: 50,
            rating: .neutral,
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_000),
            series: []
        )
    }
}
