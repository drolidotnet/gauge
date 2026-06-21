//
//  GaugeResponse.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import Foundation

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
