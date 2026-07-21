import Foundation
import SwiftUI

enum GaugeChartRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"

    var id: Self { self }

    private var dateComponent: (Calendar.Component, Int) {
        switch self {
        case .oneMonth:
            (.month, -1)
        case .threeMonths:
            (.month, -3)
        case .oneYear:
            (.year, -1)
        }
    }

    func cutoff(relativeTo date: Date, calendar: Calendar = .current) -> Date {
        let (component, value) = dateComponent
        return calendar.date(byAdding: component, value: value, to: date) ?? .distantPast
    }

    func filter(_ points: [GaugePoint]) -> [GaugePoint] {
        guard let latest = points.map(\.timestamp).max() else { return [] }
        let start = cutoff(relativeTo: latest)
        return points.filter { $0.timestamp >= start && $0.timestamp <= latest }
    }

    func filter(_ points: [GaugeHistoryPoint]) -> [GaugeHistoryPoint] {
        guard let latest = points.map(\.timestamp).max() else { return [] }
        let start = cutoff(relativeTo: latest)
        return points.filter { $0.timestamp >= start && $0.timestamp <= latest }
    }
}

/// Shared nearest-point logic keeps chart marks and text readouts aligned,
/// including paired series whose cached halves end on different dates.
enum GaugeChartSelection {
    static func nearestPoint(to date: Date, in points: [GaugePoint]) -> GaugePoint? {
        points.min {
            abs($0.timestamp.timeIntervalSince(date)) <
                abs($1.timestamp.timeIntervalSince(date))
        }
    }

    static func anchorDate(near date: Date, series: [[GaugePoint]]) -> Date? {
        nearestPoint(to: date, in: series.flatMap { $0 })?.timestamp
    }

    static func nearestHistoryPoint(
        to date: Date,
        in points: [GaugeHistoryPoint]
    ) -> GaugeHistoryPoint? {
        points.min {
            abs($0.timestamp.timeIntervalSince(date)) <
                abs($1.timestamp.timeIntervalSince(date))
        }
    }
}

struct GaugeRangePicker: View {
    @Binding var selection: GaugeChartRange

    var body: some View {
        Picker("Chart range", selection: $selection) {
            ForEach(GaugeChartRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Changes the time range for every chart")
    }
}
