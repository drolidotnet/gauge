import Foundation
import XCTest
@testable import Gauge

final class GaugeChartRangeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testRangeCutoffsUseCalendarMonthsAndYear() throws {
        let latest = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )

        XCTAssertEqual(
            GaugeChartRange.oneMonth.cutoff(relativeTo: latest, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 13))
        )
        XCTAssertEqual(
            GaugeChartRange.threeMonths.cutoff(relativeTo: latest, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 13))
        )
        XCTAssertEqual(
            GaugeChartRange.oneYear.cutoff(relativeTo: latest, calendar: calendar),
            calendar.date(from: DateComponents(year: 2025, month: 7, day: 13))
        )
    }

    func testFiltersRawAndOverallPointsAgainstLatestPoint() {
        let latest = Date(timeIntervalSince1970: 1_800_000_000)
        let inOneMonth = latest.addingTimeInterval(-(20 * 24 * 60 * 60))
        let inThreeMonths = latest.addingTimeInterval(-(60 * 24 * 60 * 60))
        let inOneYear = latest.addingTimeInterval(-(200 * 24 * 60 * 60))
        let outside = latest.addingTimeInterval(-(400 * 24 * 60 * 60))

        let dates = [outside, inOneYear, inThreeMonths, inOneMonth, latest]
        let raw = dates.map { GaugePoint(timestamp: $0, value: 1) }
        let history = dates.map {
            GaugeHistoryPoint(timestamp: $0, score: 50, rating: .neutral)
        }

        XCTAssertEqual(
            GaugeChartRange.oneMonth.filter(raw).map(\.timestamp),
            [inOneMonth, latest]
        )
        XCTAssertEqual(GaugeChartRange.threeMonths.filter(raw).count, 3)
        XCTAssertEqual(GaugeChartRange.oneYear.filter(raw).count, 4)
        XCTAssertEqual(
            GaugeChartRange.oneMonth.filter(history).map(\.timestamp),
            [inOneMonth, latest]
        )
        XCTAssertEqual(GaugeChartRange.threeMonths.filter(history).count, 3)
        XCTAssertEqual(GaugeChartRange.oneYear.filter(history).count, 4)
    }

    func testIndicatorReferenceLinesAndOverallBounds() {
        XCTAssertEqual(GaugeIndicatorKind.stockPriceStrength.referenceValue, 0)
        XCTAssertEqual(GaugeIndicatorKind.stockPriceBreadth.referenceValue, 0)
        XCTAssertEqual(GaugeIndicatorKind.safeHavenDemand.referenceValue, 0)
        XCTAssertEqual(GaugeIndicatorKind.putCallOptions.referenceValue, 1)
        XCTAssertNil(GaugeIndicatorKind.marketVolatility.referenceValue)

        let low = GaugeHistoryPoint(timestamp: .distantPast, score: -5, rating: .extremeFear)
        let high = GaugeHistoryPoint(timestamp: .distantFuture, score: 105, rating: .extremeGreed)
        XCTAssertEqual(low.displayScore, 0)
        XCTAssertEqual(high.displayScore, 100)
    }

    func testPairedScrubbingAnchorsOnceButPreservesEachActualTimestamp() throws {
        let day = 24 * 60 * 60.0
        let target = Date(timeIntervalSince1970: 1_000)
        let primary = [GaugePoint(timestamp: target, value: 10)]
        let cachedPair = [GaugePoint(timestamp: target.addingTimeInterval(-day), value: 20)]

        let anchor = try XCTUnwrap(
            GaugeChartSelection.anchorDate(near: target, series: [primary, cachedPair])
        )
        let primarySelection = GaugeChartSelection.nearestPoint(to: anchor, in: primary)
        let pairedSelection = GaugeChartSelection.nearestPoint(to: anchor, in: cachedPair)

        XCTAssertEqual(anchor, target)
        XCTAssertEqual(primarySelection?.timestamp, target)
        XCTAssertEqual(pairedSelection?.timestamp, target.addingTimeInterval(-day))
    }

    func testOverallScrubbingReturnsNearestScoreAndRating() throws {
        let target = Date(timeIntervalSince1970: 1_000)
        let points = [
            GaugeHistoryPoint(
                timestamp: target.addingTimeInterval(-100),
                score: 20,
                rating: .extremeFear
            ),
            GaugeHistoryPoint(
                timestamp: target.addingTimeInterval(10),
                score: 61,
                rating: .greed
            ),
        ]

        let selected = try XCTUnwrap(
            GaugeChartSelection.nearestHistoryPoint(to: target, in: points)
        )
        XCTAssertEqual(selected.score, 61)
        XCTAssertEqual(selected.rating, .greed)
    }
}
