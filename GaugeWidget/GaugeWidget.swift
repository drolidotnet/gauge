//
//  GaugeWidget.swift
//  GaugeWidget
//
//  Created by Oliver Drozdz on 1/7/2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GaugeEntry {
        GaugeEntry(date: Date(), score: 50, rating: "Neutral")
    }

    func getSnapshot(in context: Context, completion: @escaping (GaugeEntry) -> ()) {
        let entry = GaugeEntry(date: Date(), score: 50, rating: "Neutral")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GaugeEntry>) -> ()) {
        fetchGaugeData { score, rating in
            let entry = GaugeEntry(date: Date(), score: score, rating: rating)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    func fetchGaugeData(completion: @escaping (Int, String) -> ()) {
        guard let url = URL(string: "https://production.dataviz.cnn.io/index/fearandgreed/graphdata") else {
            completion(0, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let decoded = try? JSONDecoder().decode(GaugeResponse.self, from: data) else {
                completion(0, "Error")
                return
            }

            let score = Int(decoded.fear_and_greed.score)
            let rating = decoded.fear_and_greed.rating.capitalized
            completion(score, rating)
        }.resume()
    }
}

struct GaugeEntry: TimelineEntry {
    let date: Date
    let score: Int
    let rating: String
}

struct GaugeWidgetEntryView : View {
    var entry: GaugeEntry

    var body: some View {
        VStack {
            Text("F&G Index")
                .font(.headline)
            Text("\(entry.score)")
                .font(.system(size: 36, weight: .bold))
            Text(entry.rating)
                .font(.subheadline)
                .foregroundColor(scoreColor(entry.score))
        }
        .padding()
    }

    func scoreColor(_ score: Int) -> Color {
        let clampedScore = max(0, min(score, 100))
        let t = Double(clampedScore) / 100.0

        let red: Double
        let green: Double

        if t < 0.5 {
            red = 1.0
            green = t * 1.0
        } else {
            red = 1.0 - (t - 0.5) * 2.0
            green = 0.5 + (t - 0.5) * 1.0
        }

        let adjustedRed = pow(red, 0.9)
        let adjustedGreen = pow(green, 0.9)

        return Color(red: adjustedRed, green: adjustedGreen, blue: 0)
    }
}

struct GaugeWidget: Widget {
    let kind: String = "GaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
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

//struct GaugeResponse: Codable {
//    struct GaugeData: Codable {
//        let score: Double
//        let rating: String
//    }
//    let fear_and_greed: GaugeData
//}
