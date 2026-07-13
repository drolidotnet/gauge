import WidgetKit
import SwiftUI

struct GaugeHybridEntry: TimelineEntry {
    let date: Date
    let score: Int
    let rating: String
    let chartData: [Double]
}

struct GaugeHybridProvider: TimelineProvider {
    func placeholder(in context: Context) -> GaugeHybridEntry {
        GaugeHybridEntry(date: Date(), score: 50, rating: "Neutral", chartData: [20, 40, 60, 80, 60, 40, 20, 50, 70, 90])
    }

    func getSnapshot(in context: Context, completion: @escaping (GaugeHybridEntry) -> ()) {
        let entry = GaugeHybridEntry(date: Date(), score: 50, rating: "Neutral", chartData: [20, 40, 60, 80, 60, 40, 20, 50, 70, 90])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GaugeHybridEntry>) -> ()) {
        GaugeService.shared.fetchGaugeData { result in
            var entry: GaugeHybridEntry
            switch result {
            case .success(let response):
                let score = Int(response.fear_and_greed.score)
                let rating = response.fear_and_greed.rating.capitalized
                let chartData = response.fear_and_greed_historical?.data.map { $0.y } ?? []
                entry = GaugeHybridEntry(date: Date(), score: score, rating: rating, chartData: chartData)
            case .failure:
                entry = GaugeHybridEntry(date: Date(), score: 0, rating: "Error", chartData: [])
            }
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct GaugeHybridWidgetEntryView: View {
    var entry: GaugeHybridEntry
    var body: some View {
        ZStack {
//            Color(.darkGray)
            VStack(alignment: .leading, spacing: 8) {
                Text("F&G Index")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
//                    .padding(.top, 4)
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(entry.score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(GaugeColor.scoreColor(Double(entry.score)))
                    Text(entry.rating)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 4)
                }
                    Spacer()
                    // Mini chart
                    GeometryReader { geo in
                        let chartData = entry.chartData
                        let maxY = chartData.max() ?? 100
                        let minY = chartData.min() ?? 0
                        let points = chartData.enumerated().map { (i, y) in
                            CGPoint(
                                x: geo.size.width * CGFloat(i) / CGFloat(max(chartData.count - 1, 1)),
                                y: geo.size.height * CGFloat(1 - (y - minY) / max(1, maxY - minY))
                            )
                        }
                        Path { path in
                            if let first = points.first {
                                path.move(to: first)
                                for pt in points.dropFirst() {
                                    path.addLine(to: pt)
                                }
                            }
                        }
                        .stroke(GaugeColor.scoreColor(Double(entry.score)), lineWidth: 2)
                    }
                    .frame(height: 32)

                Spacer()

            }
//            .padding([.leading, .trailing], 12)
//            .padding([.top, .bottom], 8)
        }
    }
}

struct GaugeHybridWidget: Widget {
    let kind: String = "GaugeHybridWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GaugeHybridProvider()) { entry in
            GaugeHybridWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

#Preview(as: .systemSmall) {
    GaugeHybridWidget()
} timeline: {
    GaugeHybridEntry(date: .now, score: 62, rating: "Neutral", chartData: [20, 40, 60, 80, 60, 40, 20, 50, 70, 90])
}
