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

struct GaugeWidgetEntryView: View {
    var entry: GaugeEntry

    var body: some View {
        VStack {
            Text("F&G Index")
                .font(.headline)
            Text("\(entry.score)")
                .font(.system(size: 36, weight: .bold))
            Text(entry.rating)
                .font(.subheadline)
                .foregroundColor(GaugeColor.scoreColor(Double(entry.score)))
        }
        .padding()
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
    GaugeEntry(date: .now, score: 50, rating: "Neutral")
}
