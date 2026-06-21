//
//  GaugeViewModel.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import Foundation
import Combine

class GaugeViewModel: ObservableObject {
    @Published var currentScore: Double = 0
    @Published var currentRating: String = ""
    @Published var lastUpdated: Date? = nil
    @Published var historicalData: [GaugeHistorical.DataPoint] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func fetch() {
        isLoading = true
        errorMessage = nil
        GaugeService.shared.fetchGaugeData { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.currentScore = response.fear_and_greed.score
                    self?.currentRating = response.fear_and_greed.rating.capitalized
                    if let ts = response.fear_and_greed.timestamp, let date = ISO8601DateFormatter().date(from: ts) {
                        self?.lastUpdated = date
                    }
                    self?.historicalData = response.fear_and_greed_historical?.data ?? []
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

extension GaugeViewModel {
    static var preview: GaugeViewModel {
        let vm = GaugeViewModel()
        vm.currentScore = 72
        vm.currentRating = "Greed"
        vm.historicalData = [
            .init(x: 0, y: 20, rating: "Fear"),
            .init(x: 1, y: 40, rating: "Neutral"),
            .init(x: 2, y: 60, rating: "Greed"),
            .init(x: 3, y: 80, rating: "Extreme Greed")
        ]
        return vm
    }
}
