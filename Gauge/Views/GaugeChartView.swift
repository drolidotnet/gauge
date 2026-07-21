import Charts
import SwiftUI

struct GaugeHistoryChartView: View {
    let history: [GaugeHistoryPoint]
    let range: GaugeChartRange

    @State private var selectedDate: Date?

    private var points: [GaugeHistoryPoint] {
        range.filter(history).sorted { $0.timestamp < $1.timestamp }
    }

    private var selection: GaugeHistoryPoint? {
        guard let selectedDate else { return nil }
        return GaugeChartSelection.nearestHistoryPoint(to: selectedDate, in: points)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fear & Greed History")
                        .font(.headline)
                    Text("Overall index · 0–100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let selection {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(selection.displayScore)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(GaugePalette.ratingColor(selection.rating))
                        Text(selection.rating.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(GaugePalette.ratingColor(selection.rating))
                    }
                }
            }

            if points.isEmpty {
                ContentUnavailableView {
                    Label("History unavailable", systemImage: "chart.xyaxis.line")
                } description: {
                    Text("No overall history is available for this range.")
                }
                .frame(maxWidth: .infinity, minHeight: 210)
            } else {
                Chart {
                    ForEach(points, id: \.timestamp) { point in
                        AreaMark(
                            x: .value("Date", point.timestamp),
                            yStart: .value("Minimum", 0),
                            yEnd: .value("Score", point.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.015)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.timestamp),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.linear)
                    }

                    if let selection {
                        RuleMark(x: .value("Selected date", selection.timestamp))
                            .foregroundStyle(.secondary.opacity(0.7))

                        PointMark(
                            x: .value("Selected date", selection.timestamp),
                            y: .value("Selected score", selection.score)
                        )
                        .foregroundStyle(GaugePalette.ratingColor(selection.rating))
                        .symbolSize(60)
                    }
                }
                .frame(height: 220)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick().foregroundStyle(Color.secondary.opacity(0.35))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let score = value.as(Int.self) {
                                Text("\(score)")
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .accessibilityLabel("Overall Fear and Greed Index history")
                .accessibilityHint("Touch and drag across the chart to inspect a date")

                if let selection {
                    Text("\(selection.timestamp.formatted(date: .abbreviated, time: .omitted)) · \(selection.displayScore) · \(selection.rating.displayName)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label("Touch and drag to inspect the index", systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .onChange(of: range) { _, _ in selectedDate = nil }
    }
}
