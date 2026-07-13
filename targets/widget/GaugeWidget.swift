import WidgetKit
import SwiftUI

struct GaugeEntry: TimelineEntry {
    let date: Date
    let score: Int
    let rating: String
}

struct GaugeProvider: TimelineProvider {
    func placeholder(in context: Context) -> GaugeEntry {
        GaugeEntry(date: Date(), score: 50, rating: "Neutral")
    }

    func getSnapshot(in context: Context, completion: @escaping (GaugeEntry) -> ()) {
        completion(GaugeEntry(date: Date(), score: 50, rating: "Neutral"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GaugeEntry>) -> ()) {
        GaugeService.shared.fetchGaugeData { result in
            let entry: GaugeEntry
            switch result {
            case .success(let response):
                entry = GaugeEntry(
                    date: Date(),
                    score: Int(response.fear_and_greed.score),
                    rating: response.fear_and_greed.rating.capitalized
                )
            case .failure:
                entry = GaugeEntry(date: Date(), score: 0, rating: "Error")
            }
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

// Semicircular speedometer arc anchored to the bottom of its rect.
// progress is the fraction of the half-circle to draw (0...1).
struct SpeedometerArc: Shape {
    var progress: Double
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height) - lineWidth / 2
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 + 180 * max(0, min(progress, 1))),
            clockwise: false
        )
        return path
    }
}

struct GaugeWidgetEntryView: View {
    var entry: GaugeEntry

    private let lineWidth: CGFloat = 10

    var body: some View {
        let color = GaugeColor.scoreColor(Double(entry.score))
        VStack(spacing: 4) {
            Text("F&G Index")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            ZStack(alignment: .bottom) {
                SpeedometerArc(progress: 1, lineWidth: lineWidth)
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                SpeedometerArc(progress: Double(entry.score) / 100, lineWidth: lineWidth)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Text("\(entry.score)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(height: 64)
            Text(entry.rating)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct GaugeWidget: Widget {
    let kind: String = "GaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GaugeProvider()) { entry in
            GaugeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

#Preview(as: .systemSmall) {
    GaugeWidget()
} timeline: {
    GaugeEntry(date: .now, score: 49, rating: "Neutral")
    GaugeEntry(date: .now, score: 15, rating: "Extreme Fear")
    GaugeEntry(date: .now, score: 85, rating: "Extreme Greed")
}
