import SwiftUI

struct GaugeResponse: Codable {
    struct GaugeData: Codable {
        let score: Double
        let rating: String
        let timestamp: String?
        let previous_close: Double?
        let previous_1_week: Double?
        let previous_1_month: Double?
        let previous_1_year: Double?
    }
    let fear_and_greed: GaugeData
    let fear_and_greed_historical: GaugeHistorical?
}

struct GaugeHistorical: Codable {
    struct DataPoint: Codable {
        let x: Double // timestamp (ms)
        let y: Double // score
        let rating: String
    }
    let timestamp: Double
    let score: Double
    let rating: String
    let data: [DataPoint]
}

struct GaugeColor {
    static func scoreColor(_ score: Double) -> Color {
        let clampedScore = max(0, min(score, 100))
        let t = clampedScore / 100.0
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

class GaugeService {
    static let shared = GaugeService()
    private let url = URL(string: "https://production.dataviz.cnn.io/index/fearandgreed/graphdata")!

    func fetchGaugeData(completion: @escaping (Result<GaugeResponse, Error>) -> Void) {
        var request = URLRequest(url: url)
        // CNN's API bot-blocks (HTTP 418) unless the request looks like a real browser.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://edition.cnn.com/", forHTTPHeaderField: "Referer")
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GaugeResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
