//
//  GaugeService.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import Foundation

class GaugeService {
    static let shared = GaugeService()
    private let url = URL(string: "https://production.dataviz.cnn.io/index/fearandgreed/graphdata")!

    func fetchGaugeData(completion: @escaping (Result<GaugeResponse, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
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
