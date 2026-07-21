import Charts
import SwiftUI

struct GaugeIndicatorCardView: View {
    let kind: GaugeIndicatorKind
    let indicator: GaugeIndicator?
    let range: GaugeChartRange

    @State private var selectedDate: Date?

    private struct DisplaySeries: Identifiable {
        let id: String
        let name: String
        let valueFormat: GaugeValueFormat
        let points: [GaugePoint]
    }

    private struct SelectedValue: Identifiable {
        let id: String
        let name: String
        let timestamp: Date
        let value: Double
        let valueFormat: GaugeValueFormat
    }

    private var displaySeries: [DisplaySeries] {
        guard let indicator else { return [] }
        let allPoints = indicator.series.flatMap(\.points)
        guard let latest = allPoints.map(\.timestamp).max() else { return [] }
        let cutoff = range.cutoff(relativeTo: latest)

        return indicator.series.compactMap { series in
            let points = series.points
                .filter { $0.timestamp >= cutoff && $0.timestamp <= latest }
                .sorted { $0.timestamp < $1.timestamp }
            guard !points.isEmpty else { return nil }
            return DisplaySeries(
                id: series.id,
                name: series.displayName,
                valueFormat: series.valueFormat,
                points: points
            )
        }
    }

    private var selectedValues: [SelectedValue] {
        guard let selectedPointDate else { return [] }
        return displaySeries.compactMap { series in
            guard let point = GaugeChartSelection.nearestPoint(
                to: selectedPointDate,
                in: series.points
            ) else { return nil }
            return SelectedValue(
                id: series.id,
                name: series.name,
                timestamp: point.timestamp,
                value: point.value,
                valueFormat: series.valueFormat
            )
        }
    }

    private var selectedPointDate: Date? {
        guard let selectedDate else { return nil }
        return GaugeChartSelection.anchorDate(
            near: selectedDate,
            series: displaySeries.map(\.points)
        )
    }

    private var yDomain: ClosedRange<Double> {
        var values = displaySeries.flatMap(\.points).map(\.value)
        if let reference = kind.referenceValue {
            values.append(reference)
        }
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }

        if minimum == maximum {
            let padding = max(abs(minimum) * 0.08, 0.5)
            return (minimum - padding)...(maximum + padding)
        }

        let padding = max((maximum - minimum) * 0.1, 0.001)
        return (minimum - padding)...(maximum + padding)
    }

    private var seriesColors: [Color] {
        guard let indicator else { return [.accentColor] }
        if displaySeries.count > 1 {
            return [GaugePalette.ratingColor(indicator.rating), .secondary]
        }
        return [GaugePalette.ratingColor(indicator.rating)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if displaySeries.isEmpty {
                unavailableChart
            } else {
                chart
                selectionReadout
            }

            Text(kind.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .onChange(of: range) { _, _ in selectedDate = nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.headline)
                    Text(kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let indicator {
                    Text("\(indicator.displayScore)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(GaugePalette.ratingColor(indicator.rating))
                        .accessibilityLabel("Score \(indicator.displayScore) out of 100")
                } else {
                    Text("—")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Score unavailable")
                }
            }

            HStack(spacing: 8) {
                if let indicator {
                    Text(indicator.rating.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GaugePalette.ratingColor(indicator.rating))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(GaugePalette.ratingColor(indicator.rating).opacity(0.12), in: Capsule())

                    if indicator.isStale {
                        Label("Stale", systemImage: "clock.badge.exclamationmark")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    if let updatedAt = indicator.sourceUpdatedAt {
                        Text("Updated \(updatedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("Unavailable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.11), in: Capsule())
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(displaySeries) { series in
                ForEach(series.points, id: \.timestamp) { point in
                    LineMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Value", point.value),
                        series: .value("Series", series.name)
                    )
                    .foregroundStyle(by: .value("Series", series.name))
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }

            if let reference = kind.referenceValue {
                RuleMark(y: .value("Reference", reference))
                    .foregroundStyle(.secondary.opacity(0.65))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }

            if let selectedPointDate {
                RuleMark(x: .value("Selected date", selectedPointDate))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }

            ForEach(selectedValues) { selection in
                PointMark(
                    x: .value("Selected date", selection.timestamp),
                    y: .value("Selected value", selection.value)
                )
                .foregroundStyle(by: .value("Series", selection.name))
                .symbolSize(46)
            }
        }
        .frame(height: 190)
        .chartYScale(domain: yDomain)
        .chartForegroundStyleScale(
            domain: displaySeries.map(\.name),
            range: seriesColors
        )
        .chartLegend(displaySeries.count > 1 ? .visible : .hidden)
        .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisTick().foregroundStyle(Color.secondary.opacity(0.35))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(kind.valueFormat.format(amount, compact: true))
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .accessibilityLabel("\(kind.title) history")
        .accessibilityHint("Touch and drag across the chart to inspect values")
    }

    private var selectionReadout: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let date = selectedPointDate, !selectedValues.isEmpty {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        selectedValueLabels
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        selectedValueLabels
                    }
                }
            } else {
                Label("Touch and drag to inspect values", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
    }

    @ViewBuilder
    private var selectedValueLabels: some View {
        ForEach(selectedValues) { selection in
            Text(selectedValueLabel(selection))
                .font(.caption.monospacedDigit())
                .lineLimit(1)
        }
    }

    private var unavailableChart: some View {
        ContentUnavailableView {
            Label("Chart unavailable", systemImage: "chart.xyaxis.line")
        } description: {
            Text("No recent data is available for this indicator.")
        }
        .frame(maxWidth: .infinity, minHeight: 190)
    }

    private func selectedValueLabel(_ selection: SelectedValue) -> String {
        let value = selection.valueFormat.format(selection.value)
        guard let selectedPointDate,
              !Calendar.current.isDate(selection.timestamp, inSameDayAs: selectedPointDate) else {
            return "\(selection.name): \(value)"
        }
        let date = selection.timestamp.formatted(.dateTime.month(.abbreviated).day())
        return "\(selection.name): \(value) (\(date))"
    }
}
